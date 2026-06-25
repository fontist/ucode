# frozen_string_literal: true

RSpec.describe Ucode do
  it "exposes a VERSION string" do
    expect(Ucode::VERSION).to be_a(String)
    expect(Ucode::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "exposes a memoized Config via .configuration" do
    expect(Ucode.configuration).to be_a(Ucode::Config)
    expect(Ucode.configuration).to equal(Ucode.configuration)
  end

  it "yields the config to .configure" do
    original = Ucode.configuration.parallel_workers
    begin
      Ucode.configure { |c| c.parallel_workers = original + 1 }
      expect(Ucode.configuration.parallel_workers).to eq(original + 1)
    ensure
      Ucode.configuration.parallel_workers = original
    end
  end
end
