# TODO 01 — PDF fetch validation

## Status

Pending.

## Goal

Raise a typed `Ucode::CodeChartNotFoundError` when a Unicode Code
Charts PDF cannot be downloaded or fails content validation. The REQ
(R1) requires:

- HTTP 4xx / 5xx → `CodeChartNotFoundError`
- `Content-Type: application/pdf`
- First 4 bytes are `%PDF`

## Files

- `lib/ucode/error.rb` — add `Ucode::CodeChartNotFoundError` under the
  `GlyphError` subtree.
- `lib/ucode.rb` — add an `autoload` for the new class so any rescue
  clause triggers one load of `error.rb`.
- `lib/ucode/fetch/http.rb` — extend `Http.get` with an optional
  `validate:` keyword. When `validate: :pdf`, after a successful
  download, verify the `Content-Type` response header starts with
  `application/pdf` and the first 4 bytes of the body are `%PDF`.
- `lib/ucode/fetch/code_charts.rb` — pass `validate: :pdf` to `Http.get`
  for every chart PDF download.
- `spec/ucode/fetch/code_charts_spec.rb` (new) — cover the happy path
  and the validation failure modes.

## Design

### Why a new error class

`FetchError` already covers transport failures, but it doesn't carry
"this URL produced an HTML error page / 404 / non-PDF body" semantics.
Splitting the type keeps existing `rescue Ucode::FetchError` callers
from accidentally swallowing the typed signal that "we expected a PDF
and didn't get one" — which is a different problem class from "the
network was down."

`CodeChartNotFoundError < Ucode::Error` (under `GlyphError`) reflects
the REQ's framing: the chart for the requested block is not
obtainable.

### Why `validate:` is optional on `Http.get`

`Http` is the single network boundary (per the comment at the top of
`http.rb`). All callers funnel through it. Adding an optional
keyword keeps the MECE pattern intact: non-PDF callers (UCD zip,
Unihan zip, font zip) pass nothing; the single PDF caller passes
`validate: :pdf`. No second network boundary is needed.

### Why no separate "magic bytes" check class

Magic-byte verification is 4 lines of code; extracting it into a
class would be ceremony. Inline check after `write_body`, raising
the typed error with the offending content-type or magic bytes in
the context payload.

## Acceptance

- `Http.get(url, dest:, validate: :pdf)` raises
  `CodeChartNotFoundError` (a) when the response Content-Type is not
  `application/pdf`, (b) when the first 4 bytes are not `%PDF`.
- `Fetch::CodeCharts.call(version, block_first_cps: [...])` raises
  `CodeChartNotFoundError` when the unicode.org endpoint returns
  4xx/5xx or non-PDF content.
- Existing callers of `Http.get` that don't pass `validate:` are
  unchanged.
- Spec coverage: happy path, HTTP 404, wrong content-type, truncated
  body missing the `%PDF` magic.

## Out of scope

- SHA-256 verification of the PDF — that's a downstream concern (the
  Code Charts are not versioned by hash on unicode.org).
- Resumable / partial downloads — the existing `Http` writes a
  `.part` then renames; that's sufficient.