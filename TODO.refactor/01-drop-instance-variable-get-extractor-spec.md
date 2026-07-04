# TODO 01 — Drop `instance_variable_get` from extractor_spec

## Status

Pending. Audit finding V1 (critical rule violation).

## Why

`spec/ucode/code_chart/extractor_spec.rb:58-74` pokes at private state
(`@block`, `@pdf_path`, `@tier1_sources`, `@pillar3_source`, `@cache_dir`)
via `instance_variable_get` — six calls.

The global rule (~/.claude/CLAUDE.md §"On Assumptions / forbidden
patterns"):

> NEVER use `instance_variable_set` or `instance_variable_get`.
> Accessing another object's instance variables breaks encapsulation.
> If you need the data, add a public accessor or rethink the ownership.

These specs don't test behavior — they test injection mechanics. The
behavioral specs (`#extract` block) already prove injection works
through the resulting `Result` set.

## Files

- `spec/ucode/code_chart/extractor_spec.rb` — drop the entire
  `describe "#initialize"` block (lines 55-76).

## Acceptance

- No `instance_variable_get` / `instance_variable_set` anywhere in
  `spec/ucode/code_chart/`.
- `bundle exec rspec spec/ucode/code_chart/` still passes (skipped
  when mutool is absent, as today).
- `grep -r "instance_variable" spec/ucode/code_chart/` returns nothing.
