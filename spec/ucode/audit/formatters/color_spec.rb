# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::Formatters::Color do
  describe ".enabled? when NO_COLOR is unset" do
    around do |example|
      previous = ENV["NO_COLOR"]
      ENV.delete("NO_COLOR")
      example.run
    ensure
      ENV["NO_COLOR"] = previous
    end

    it { expect(described_class).to be_enabled }

    it "wraps text in ANSI bold sequences" do
      expect(described_class.bold("hi")).to include("\e[1m")
      expect(described_class.bold("hi")).to include("hi")
    end

    it "wraps text in ANSI dim sequences" do
      expect(described_class.dim("hi")).to include("\e[2m")
    end

    it "wraps text in ANSI color sequences" do
      expect(described_class.cyan("hi")).to  include("\e[36m")
      expect(described_class.green("hi")).to include("\e[32m")
      expect(described_class.red("hi")).to   include("\e[31m")
    end

    it "always terminates with a RESET" do
      expect(described_class.bold("hi")).to end_with("\e[0m")
    end
  end

  describe ".enabled? when NO_COLOR is set" do
    around do |example|
      previous = ENV["NO_COLOR"]
      ENV["NO_COLOR"] = "1"
      example.run
    ensure
      ENV["NO_COLOR"] = previous
    end

    it { expect(described_class).not_to be_enabled }

    it "returns text unchanged" do
      expect(described_class.bold("hi")).to eq("hi")
      expect(described_class.dim("hi")).to eq("hi")
      expect(described_class.cyan("hi")).to eq("hi")
      expect(described_class.green("hi")).to eq("hi")
      expect(described_class.red("hi")).to eq("hi")
    end
  end

  describe ".enabled? when NO_COLOR is empty string" do
    around do |example|
      previous = ENV["NO_COLOR"]
      ENV["NO_COLOR"] = ""
      example.run
    ensure
      ENV["NO_COLOR"] = previous
    end

    it "treats empty as unset (enabled)" do
      expect(described_class).to be_enabled
    end
  end
end
