# frozen_string_literal: true

require "pathname"
require "yaml"

module Ucode
  # Sorted, run-length-encoded lookup table over Unicode codepoints.
  #
  # One Index answers "what <thing> does codepoint N belong to?" for one
  # property (block, or script). Lookup is O(log N) via `bsearch_index`.
  #
  # Two ways to construct:
  #   - `Index.from_triples([[first, last, name], ...])`
  #   - `Index.load(path)` from a YAML file previously written by `#save`.
  #
  # The YAML form is the dependency-free alternative to SQLite — same
  # query API, simpler ops. Pick whichever fits the deployment.
  class Index
    include Enumerable

    def initialize(entries)
      @entries = entries.sort
    end

    attr_reader :entries

    def each(&block)
      @entries.each(&block)
    end

    def size
      @entries.size
    end

    # @param codepoint [Integer]
    # @return [String, nil] the name of the range covering `codepoint`, or nil
    def lookup(codepoint)
      idx = bsearch_index(codepoint)
      idx && @entries[idx].name
    end

    # Enumerate every range whose [first_cp, last_cp] overlaps the
    # inclusive query range. Returns a lazy Enumerator when called
    # without a block.
    # @param first [Integer]
    # @param last [Integer]
    # @return [Enumerator<RangeEntry>, nil]
    def each_overlapping(first, last, &block)
      return enum_for(:each_overlapping, first, last) unless block_given?

      start_idx = bsearch_first_overlap(first)
      return if start_idx.nil?

      @entries[start_idx..].each do |entry|
        break if entry.first_cp > last

        yield entry if entry.last_cp >= first
      end
    end

    # Serialize to a YAML file.
    # @param path [String, Pathname]
    # @return [void]
    def save(path)
      File.open(path, "w") do |file|
        YAML.dump(@entries.map(&:to_h), file)
      end
    end

    # Load from a YAML file previously written by #save.
    # @param path [String, Pathname]
    # @return [Index]
    def self.load(path)
      hashes = YAML.load_file(path)
      new(hashes.map { |h| RangeEntry.from_h(h) })
    end

    # Build an Index from raw [first_cp, last_cp, name] triples.
    # @param triples [Array<Array(Integer, Integer, String)>]
    # @return [Index]
    def self.from_triples(triples)
      new(triples.map { |first, last, name| RangeEntry.new(first, last, name) })
    end

    private

    # bsearch_index integer-mode convention: -1 = search LEFT, +1 = RIGHT,
    # 0 = match. See Coordinator#find_in_range for the same convention.
    def bsearch_index(codepoint)
      @entries.bsearch_index do |entry|
        if codepoint < entry.first_cp
          -1
        elsif codepoint > entry.last_cp
          1
        else
          0
        end
      end
    end

    # Boolean-mode bsearch: first entry whose `last_cp >= first`.
    def bsearch_first_overlap(first)
      @entries.bsearch_index { |entry| entry.last_cp >= first }
    end
  end
end
