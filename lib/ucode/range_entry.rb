# frozen_string_literal: true

module Ucode
  # Value object representing one row in a run-length-encoded UCD index.
  #
  # Sorted by `first_cp`. Entries within a single Index are disjoint (no
  # overlapping ranges). This is a leaf value object — not a
  # `Lutaml::Model::Serializable` model — because it has no wire shape,
  # no nested types, and is consumed only by the YAML-backed Index. The
  # `to_h` / `from_h` pair below is the deliberate serialization contract
  # for the YAML file format and is exempt from the no-to_h rule by
  # design (that rule covers model classes only).
  class RangeEntry
    include Comparable

    attr_reader :first_cp, :last_cp, :name

    def initialize(first_cp, last_cp, name)
      @first_cp = first_cp
      @last_cp = last_cp
      @name = name
    end

    def covers?(codepoint)
      codepoint >= @first_cp && codepoint <= @last_cp
    end

    def size
      @last_cp - @first_cp + 1
    end

    def <=>(other)
      [@first_cp, @last_cp] <=> [other.first_cp, other.last_cp]
    end

    def ==(other)
      other.is_a?(RangeEntry) &&
        @first_cp == other.first_cp &&
        @last_cp == other.last_cp &&
        @name == other.name
    end
    alias eql? ==

    def hash
      [@first_cp, @last_cp, @name].hash
    end

    def to_h
      { first_cp: @first_cp, last_cp: @last_cp, name: @name }
    end

    def self.from_h(hash)
      new(hash[:first_cp] || hash["first_cp"],
          hash[:last_cp] || hash["last_cp"],
          hash[:name] || hash["name"])
    end
  end
end
