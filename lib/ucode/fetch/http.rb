# frozen_string_literal: true

require "net/http"
require "uri"
require "fileutils"
require "pathname"

module Ucode
  module Fetch
    # Shared HTTP wrapper. Single network boundary for the whole project.
    #
    # Streaming download with retries and exponential backoff. Raises
    # Ucode::NetworkError on final failure (after `http_retries` attempts).
    module Http
      DEFAULT_BACKOFF = [1, 2, 4, 8, 16].freeze
      private_constant :DEFAULT_BACKOFF

      class << self
        # Stream `url` to `dest` (a Pathname or String path).
        #
        # @param url [String, URI] full URL.
        # @param dest [Pathname, String] destination file path. Parent
        #   directory is created if absent.
        # @param retries [Integer, nil] override Config.http_retries.
        # @param timeout [Integer, nil] override Config.http_timeout.
        # @param validate [Symbol, nil] when `:pdf`, after a successful
        #   download verify (a) Content-Type starts with `application/pdf`
        #   and (b) the first 4 bytes of the body are `%PDF`. Raises
        #   {Ucode::CodeChartNotFoundError} with the offending header
        #   value in `context:` on failure. nil = no validation (the
        #   default for non-PDF callers like UcdZip and UnihanZip).
        # @param not_found_class [Class, nil] when set, HTTP 4xx
        #   responses raise this class (instantiated with message +
        #   context) instead of being treated as retriable transport
        #   errors. nil = 4xx is retriable like any other non-success.
        # @return [Pathname] destination path on success.
        # @raise [Ucode::NetworkError] if all retries fail.
        # @raise [Ucode::CodeChartNotFoundError] when `validate: :pdf`
        #   and the response fails content validation.
        # @raise [<not_found_class>] when `not_found_class:` is set
        #   and the server returns 4xx.
        def get(url, dest:, retries: nil, timeout: nil, validate: nil,
                not_found_class: nil)
          uri = url.is_a?(URI) ? url : URI(url)
          destination = Pathname.new(dest)
          destination.dirname.mkpath

          attempts = retries || Ucode.configuration.http_retries
          read_timeout = timeout || Ucode.configuration.http_timeout
          backoff_sequence = DEFAULT_BACKOFF.take(attempts + 1)

          last_error = nil
          (attempts + 1).times do |attempt|
            response = stream_to(uri, destination, read_timeout,
                                 not_found_class: not_found_class)
            validate_response!(validate, response, destination) if validate
            return destination
          rescue ValidationFailure => e
            raise e.cause
          rescue StandardError => e
            last_error = e
            sleep_for = backoff_sequence[attempt] || backoff_sequence.last
            Ucode.configuration.logger&.warn do
              "Http GET #{uri} failed (attempt #{attempt + 1}/#{attempts + 1}): " \
                "#{e.class}: #{e.message}; retrying in #{sleep_for}s"
            end
            sleep(sleep_for)
          end

          raise Ucode::NetworkError.new(
            "GET #{uri} failed after #{attempts + 1} attempts",
            context: { url: uri.to_s, last_error: last_error&.message },
          )
        end

        private

        # Internal carrier for a validation failure inside a retry
        # attempt. Re-raised from the loop so the response body (which
        # is partial on retries) isn't double-validated against
        # truncated bytes.
        class ValidationFailure < StandardError
          attr_reader :cause

          def initialize(cause)
            @cause = cause
            super(cause.message)
          end
        end

        def stream_to(uri, destination, read_timeout, not_found_class: nil)
          response = nil
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                              read_timeout: read_timeout) do |http|
            request = Net::HTTP::Get.new(uri)
            http.request(request) do |r|
              unless r.is_a?(Net::HTTPSuccess)
                raise ValidationFailure.new(not_found_error(not_found_class, uri, r)) if not_found_class && r.is_a?(Net::HTTPClientError)

                raise "HTTP #{r.code} #{r.message}"
              end

              write_body(r, destination)
              response = r
            end
          end
          response or raise "no response received"
        end

        # Builds the not-found error (e.g. CodeChartNotFoundError)
        # for a 4xx response, fed through ValidationFailure so the
        # retry loop in `get` doesn't re-attempt a permanent miss.
        def not_found_error(klass, uri, response)
          klass.new(
            "HTTP #{response.code} #{response.message}",
            context: { url: uri.to_s, status: response.code.to_i },
          )
        end

        def write_body(response, destination)
          partial = destination.sub_ext("#{destination.extname}.part")
          File.open(partial, "wb") do |file|
            response.read_body { |chunk| file.write(chunk) }
          end
          File.rename(partial.to_s, destination.to_s)
        end

        # Verifies Content-Type and magic bytes for a downloaded file.
        # Raises ValidationFailure carrying a CodeChartNotFoundError so
        # the retry loop in `get` doesn't re-attempt a download that's
        # structurally invalid (only the transport is retriable).
        def validate_response!(mode, response, destination)
          case mode
          when :pdf then validate_pdf!(response, destination)
          else raise ArgumentError, "unknown validate mode: #{mode.inspect}"
          end
        end

        PDF_CONTENT_TYPE_PREFIX = "application/pdf"
        PDF_MAGIC = "%PDF"
        private_constant :PDF_CONTENT_TYPE_PREFIX, :PDF_MAGIC

        def validate_pdf!(response, destination)
          content_type = response["Content-Type"].to_s
          unless content_type.start_with?(PDF_CONTENT_TYPE_PREFIX)
            raise ValidationFailure.new(
              Ucode::CodeChartNotFoundError.new(
                "expected Content-Type application/pdf, got #{content_type.inspect}",
                context: { url: response.uri.to_s, content_type: content_type },
              ),
            )
          end

          # Re-open the destination file and peek at the first 4 bytes.
          # The response body has already been written to disk by
          # `stream_to`; we don't re-read from the response (which is
          # consumed by then).
          magic = File.open(destination, "rb") { |f| f.read(4) }
          unless magic == PDF_MAGIC
            raise ValidationFailure.new(
              Ucode::CodeChartNotFoundError.new(
                "expected %PDF magic bytes, got #{magic.inspect}",
                context: { url: response.uri.to_s, magic: magic },
              ),
            )
          end
        end
      end
    end
  end
end
