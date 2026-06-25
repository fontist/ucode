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
        # @return [Pathname] destination path on success.
        # @raise [Ucode::NetworkError] if all retries fail.
        def get(url, dest:, retries: nil, timeout: nil)
          uri = url.is_a?(URI) ? url : URI(url)
          destination = Pathname.new(dest)
          destination.dirname.mkpath

          attempts = retries || Ucode.configuration.http_retries
          read_timeout = timeout || Ucode.configuration.http_timeout
          backoff_sequence = DEFAULT_BACKOFF.take(attempts + 1)

          last_error = nil
          (attempts + 1).times do |attempt|
            return stream_to(uri, destination, read_timeout)
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

        def stream_to(uri, destination, read_timeout)
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                              read_timeout: read_timeout) do |http|
            request = Net::HTTP::Get.new(uri)
            http.request(request) do |response|
              unless response.is_a?(Net::HTTPSuccess)
                raise "HTTP #{response.code} #{response.message}"
              end

              write_body(response, destination)
            end
          end
          destination
        end

        def write_body(response, destination)
          partial = destination.sub_ext("#{destination.extname}.part")
          File.open(partial, "wb") do |file|
            response.read_body { |chunk| file.write(chunk) }
          end
          File.rename(partial.to_s, destination.to_s)
        end
      end
    end
  end
end
