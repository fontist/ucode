# 02. CI + quality

**Goal**: GitHub Actions runs `rake` (spec + rubocop) on every push and PR. Coverage is
reported. The same checks run locally with no extra setup.

**Depends on**: 01.

**Files**:
- `.github/workflows/ci.yml` — matrix on Ruby 3.1, 3.2, 3.3. Steps: checkout, `setup-ruby`,
  `bundle install`, `bundle exec rake`.
- `.github/workflows/release.yml` — later; placeholder only.
- `Rakefile` — `task default: [:spec, :rubocop]`; `task :spec => "spec:all"`.
- `spec/spec_helper.rb` — already created in TODO 01; add `SimpleCov.start` with minimum
  coverage gate at 80% (raise later).

## Tasks

- [ ] Author CI workflow; run on `push` and `pull_request`.
- [ ] Pin bundler version compatible with each Ruby.
- [ ] Add coverage gate (fail CI if coverage drops below 80%).
- [ ] Document in README how to run a single spec locally.

## Acceptance criteria

- CI runs green on a no-op PR.
- Coverage report appears in CI artifacts.
- `bundle exec rake` is the only command needed for local pre-push.
