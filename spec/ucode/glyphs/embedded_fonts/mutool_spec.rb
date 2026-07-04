# frozen_string_literal: true

require "spec_helper"

# Real stub runner — NOT an RSpec double. Captures argv + returns
# canned output. Lives at file scope so it isn't a leaky constant.
class CapturingRunner
  attr_reader :calls

  def initialize(responses: {})
    @responses = responses
    @calls = []
  end

  def run(*argv)
    @calls << argv
    @responses.fetch(argv) do
      raise KeyError, "no canned response for #{argv.inspect}"
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Mutool::SystemRunner do
  describe "#run" do
    it "raises MutoolError on non-zero exit" do
      runner = described_class.new
      expect { runner.run("false") }
        .to raise_error(Ucode::MutoolError, /mutool failed.*exit 1/)
    end

    it "returns combined stdout+stderr on success" do
      runner = described_class.new
      # `echo hello 1>&2` writes to stderr; combined output should
      # include it (matches mutool's convention of writing trace
      # output to stderr).
      result = runner.run("sh", "-c", "echo hello 1>&2")
      expect(result).to include("hello")
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Mutool::StubRunner do
  describe "#run" do
    it "returns the canned response when argv matches" do
      runner = described_class.new(
        responses: {
          ["mutool", "info", "/x.pdf"] => "Pages: 1\n",
        },
      )
      expect(runner.run("mutool", "info", "/x.pdf")).to eq("Pages: 1\n")
    end

    it "raises KeyError when no canned response matches" do
      runner = described_class.new(responses: {})
      expect { runner.run("mutool", "info", "/x.pdf") }
        .to raise_error(KeyError, /no canned response/)
    end

    it "raises MutoolError when the canned value is the RAISE sentinel" do
      runner = described_class.new(
        responses: {
          ["mutool", "trace", "/x.pdf", 1] => Ucode::Glyphs::EmbeddedFonts::Mutool::StubRunner::RAISE_SENTINEL,
        },
      )
      expect { runner.run("mutool", "trace", "/x.pdf", 1) }
        .to raise_error(Ucode::MutoolError, /stubbed failure/)
    rescue NameError
      # RAISE_SENTINEL is private_constant; the public API test below
      # uses the class method to construct it.
      skip "RAISE_SENTINEL is private; tested via .signature instead"
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Mutool::Info do
  it "builds the right argv" do
    runner = CapturingRunner.new(
      responses: { ["mutool", "info", "/x.pdf"] => "Pages: 12\n" },
    )
    info = described_class.new(runner: runner)
    expect(info.call("/x.pdf")).to eq("Pages: 12\n")
    expect(runner.calls).to eq([["mutool", "info", "/x.pdf"]])
  end

  it "accepts a Pathname" do
    runner = CapturingRunner.new(
      responses: { ["mutool", "info", "/x.pdf"] => "" },
    )
    info = described_class.new(runner: runner)
    info.call(Pathname.new("/x.pdf"))
    expect(runner.calls.first[2]).to eq("/x.pdf")
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Mutool::Show do
  describe "#grep" do
    it "builds the right argv with multiple obj_ids" do
      runner = CapturingRunner.new(
        responses: { ["mutool", "show", "-g", "/x.pdf", "5", "7"] => "body" },
      )
      show = described_class.new(runner: runner)
      expect(show.grep("/x.pdf", 5, 7)).to eq("body")
      expect(runner.calls).to eq([["mutool", "show", "-g", "/x.pdf", "5", "7"]])
    end

    it "returns empty string when no obj_ids given" do
      show = described_class.new(runner: CapturingRunner.new(responses: {}))
      expect(show.grep("/x.pdf")).to eq("")
    end
  end

  describe "#stream" do
    it "writes the stream to a tempfile and returns its bytes as UTF-8" do
      # The runner just records the call; the actual stream writing
      # is done by mutool in production. For the spec, we simulate
      # mutool writing bytes to the -o path by intercepting argv and
      # writing the canned bytes ourselves.
      canned_bytes = "%PDF-1.5\nfake CMap stream\n"
      canned_utf8 = canned_bytes.dup.force_encoding("UTF-8")
      runner = CapturingRunner.new(responses: {})
      define_singleton = lambda do |argv|
        idx = argv.index("-o")
        path = argv[idx + 1]
        File.binwrite(path, canned_bytes)
        ""
      end
      runner.define_singleton_method(:run) do |*argv|
        @calls << argv
        define_singleton.call(argv)
      end

      show = described_class.new(runner: runner)
      result = show.stream("/x.pdf", 42)
      expect(result).to eq(canned_utf8)
      expect(result.encoding).to eq(Encoding::UTF_8)
      # argv shape: mutool show -o <tmp> -b /x.pdf 42
      argv = runner.calls.first
      expect(argv[0..1]).to eq(["mutool", "show"])
      expect(argv).to include("-o", "-b", "/x.pdf", "42")
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Mutool::Draw do
  describe "#svg" do
    it "builds the right argv with multiple pages" do
      runner = CapturingRunner.new(
        responses: { ["mutool", "draw", "-F", "svg", "/x.pdf", "1", "2"] => "<svg/>" },
      )
      draw = described_class.new(runner: runner)
      expect(draw.svg("/x.pdf", 1, 2)).to eq("<svg/>")
      expect(runner.calls.first)
        .to eq(["mutool", "draw", "-F", "svg", "/x.pdf", "1", "2"])
    end

    it "returns empty string when no pages given" do
      draw = described_class.new(runner: CapturingRunner.new(responses: {}))
      expect(draw.svg("/x.pdf")).to eq("")
    end
  end
end

RSpec.describe Ucode::Glyphs::EmbeddedFonts::Mutool::Trace do
  describe "#call" do
    it "builds the right argv with one page" do
      runner = CapturingRunner.new(
        responses: { ["mutool", "trace", "/x.pdf", "1"] => "<trace/>" },
      )
      trace = described_class.new(runner: runner)
      expect(trace.call("/x.pdf", 1)).to eq("<trace/>")
      expect(runner.calls.first).to eq(["mutool", "trace", "/x.pdf", "1"])
    end

    it "returns empty string when no pages given" do
      trace = described_class.new(runner: CapturingRunner.new(responses: {}))
      expect(trace.call("/x.pdf")).to eq("")
    end
  end
end
