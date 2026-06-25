# 06. Fetchers — UCD.zip, Unihan.zip, per-block PDFs

**Goal**: Download Unicode source archives and Code Charts PDFs into the cache.
Idempotent: skip files already present unless `force:`.

**Depends on**: 04, 05.

**Files**:
- `lib/ucode/fetch.rb` — namespace hub.
- `lib/ucode/fetch/ucd_zip.rb`
- `lib/ucode/fetch/unihan_zip.rb`
- `lib/ucode/fetch/code_charts.rb`
- `lib/ucode/fetch/http.rb` — shared HTTP wrapper with retries, timeout, content-length
  check (extracted so all three fetchers share it).
- `spec/ucode/fetch/http_spec.rb` — uses `WebMock` or similar (allowed: it's a system
  boundary).
- `spec/ucode/fetch/ucd_zip_spec.rb` etc.

## Tasks

- [ ] Implement `Ucode::Fetch::Http.get(url, dest:, retries:, timeout:)` — streams to
      `dest`, retries with exponential backoff, raises `Ucode::NetworkError` on final
      failure.
- [ ] `Ucode::Fetch::UcdZip.call(version, force:)`:
      - URL: `https://www.unicode.org/Public/<version>/ucd/UCD.zip`
      - Cache path: `Cache.version_dir(version)/ucd.zip`
      - Unzip into `Cache.ucd_dir(version)` (delete stale first if `force:`).
- [ ] `Ucode::Fetch::UnihanZip.call(version, force:)`:
      - URL: `https://www.unicode.org/Public/<version>/ucd/Unihan.zip`
      - Same pattern.
- [ ] `Ucode::Fetch::CodeCharts.call(version, block_ids:, force:)`:
      - For each block ID (e.g. `ASCII`, `CJK_Ext_A`), compute the per-block PDF URL
        `https://www.unicode.org/charts/PDF/U<XXXX>.pdf` where `XXXX` is the block's
        first codepoint zero-padded to 4 digits (5–6 digits for planes > 0).
      - Stream into `Cache.pdfs_dir(version)/U<XXXX>.pdf`.
      - Skip existing unless `force:`.

## Acceptance criteria

- Running `UcdZip.call("17.0.0", force: false)` twice downloads once.
- Re-running after `force: true` re-downloads.
- Network failure raises `Ucode::NetworkError` after the configured retry count.
- All fetchers log progress via `Ucode.configuration.logger`.

## Architectural notes

- **OCP**: `Http` is the single network boundary. Adding a new source type (e.g. CLDR
  emoji annotations later) means a new fetcher class that calls `Http.get`, not a new
  HTTP stack.
- **Idempotency**: every fetcher must be safely re-runnable. This is critical for CI and
  for resuming interrupted builds.
- Per-block PDF URLs are derived from block metadata (TODO 18 produces a `block_id →
  first_codepoint` map). TODO 06 may take a temporary hardcode list until TODO 18 lands;
  reconcile then.
