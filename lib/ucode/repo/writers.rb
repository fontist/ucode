# frozen_string_literal: true

module Ucode
  module Repo
    # Per-concern writer classes, one per output file kind. Each
    # conforms to the `#write → Integer` interface (returns the count
    # of files written). Composed by AggregateWriter#flush — adding a
    # new aggregate = one writer class + one line in AggregateWriter.
    module Writers
      autoload :PlanesWriter,          "ucode/repo/writers/planes_writer"
      autoload :BlocksWriter,          "ucode/repo/writers/blocks_writer"
      autoload :ScriptsWriter,         "ucode/repo/writers/scripts_writer"
      autoload :IndexesWriter,         "ucode/repo/writers/indexes_writer"
      autoload :RelationshipsWriter,   "ucode/repo/writers/relationships_writer"
      autoload :EnumsWriter,           "ucode/repo/writers/enums_writer"
      autoload :NamedSequencesWriter,  "ucode/repo/writers/named_sequences_writer"
      autoload :ManifestWriter,        "ucode/repo/writers/manifest_writer"
    end
  end
end
