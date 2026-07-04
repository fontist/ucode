# TODO 05 — Replace `respond_to?(:to_s)` in spec_cleanup.rb

## Status

Pending. Audit finding (rule violation).

## Why

`spec/support/spec_cleanup.rb:28`:

```ruby
resolved = path.respond_to?(:to_s) ? path.to_s : path
```

The global rule:

> NEVER use `respond_to?` for type checking. Use `is_a?` for type
> checks, or better yet, design the type hierarchy so the check
> isn't needed.

`respond_to?(:to_s)` is duck-typing for a method that **every
Object** has. The conditional is dead code — `path.to_s` always
works. The check hides a non-existent edge case and suggests the
author wasn't sure what type `path` is.

A separate `respond_to?(:enrich)` in `spec/ucode/coordinator/
enrichment_spec.rb:21` is also a weak test — it asserts the module
responds to `enrich` rather than asserting the enrichment actually
enriches. Out of scope for this TODO (covered by enrichment specs
generally) but flagged here.

## Files

- `spec/support/spec_cleanup.rb`.

## Design

```ruby
def safe_remove(path)
  return if Gem.win_platform?
  return unless path

  FileUtils.remove_entry_secure(path.to_s) if File.exist?(path.to_s)
rescue Errno::ENOTEMPTY, Errno::EACCES, Errno::ENOENT
end
```

Every Object responds to `to_s`, so `path.to_s` is unconditional.
The `File.exist?` check now takes the string form (one extra `to_s`
call is negligible compared to the syscall).

## Acceptance

- `grep -n "respond_to?" spec/support/spec_cleanup.rb` returns
  nothing.
- `bundle exec rspec` still passes (cleanup behavior unchanged).
