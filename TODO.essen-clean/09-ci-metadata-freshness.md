# TODO 09 — CI guard: metadata freshness check

## Status

Pending. Depends on TODOs 05, 06.

## Context

Generated metadata modules (`metadata/v17_0_0.rb`) can go stale if
someone changes the generator or adds a new UCD source but forgets to
regenerate. This TODO adds a CI check that verifies the committed
metadata matches what the generator would produce.

## Approach

A spec that, for each supported version whose UCD data is cached on
the CI runner:

1. Runs the generator in-memory (no file write)
2. Compares the output with the committed module
3. Fails if they differ

## Spec

```ruby
# spec/ucode/unicode/metadata_freshness_spec.rb
RSpec.describe "metadata freshness", :requires_ucd do
  Ucode::Unicode::SUPPORTED_VERSIONS.each do |version|
    next unless Ucode::Cache.cached?(version) # skip if UCD not downloaded

    context "Unicode #{version}" do
      it "committed metadata matches generator output" do
        skip "UCD not cached for #{version}" unless Ucode::Cache.cached?(version)

        generated = Ucode::Unicode::MetadataWriter.generate(version: version)
        committed = read_committed_module(version)

        expect(generated).to eq(committed)
      end
    end
  end
end
```

## When to run

This spec requires the full UCD download, so it should:
- Run in CI (which has `ucode fetch ucd` as a setup step)
- Skip locally when UCD is not cached (`skip "UCD not cached"`)

## Failure message

```
Metadata for Unicode 17.0.0 is stale.
Run: bin/ucode emit-metadata --version 17.0.0
Then commit the regenerated file.
```

## Acceptance criteria

- Spec exists and runs in CI
- Passes when metadata is fresh
- Fails with a clear message when metadata is stale
- Skips gracefully when UCD is not cached
