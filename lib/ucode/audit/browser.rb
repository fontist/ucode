# frozen_string_literal: true

require "pathname"

module Ucode
  module Audit
    # Standalone HTML browsers for Mode 2 audit output.
    #
    # Two pages:
    #
    #   - {Browser::FacePage}   — one face's audit, fully self-contained
    #     (no external CSS/JS), with JSON inlined for instant render via
    #     `file://`. Block expansion and codepoint detail lazy-fetch
    #     the chunks emitted by {Emitter::FaceDirectory}.
    #   - {Browser::LibraryPage} — one library's index, also self-contained,
    #     with cards linking into each face page.
    #
    # Both pages reuse the chunk files emitted by {Emitter} — they don't
    # duplicate the JSON, they just inline the overview slice that the
    # initial render needs.
    module Browser
      TEMPLATE_DIR = Pathname.new(__dir__).join("browser/templates")
      private_constant :TEMPLATE_DIR

      autoload :Template,    "ucode/audit/browser/template"
      autoload :FacePage,    "ucode/audit/browser/face_page"
      autoload :LibraryPage, "ucode/audit/browser/library_page"
    end
  end
end
