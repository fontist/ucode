# 07 — Models::Audit port

## Goal

Port the `Fontisan::Models::Audit::*` lutaml-model classes (15 files)
to `Ucode::Models::Audit::*` with the schema adjustments from
`TODO.new/02-audit-schema-design.md`. Pure data classes — no font
parsing logic.

## Files to create

One class per file, plus the namespace hub:

```
lib/ucode/models/audit.rb
lib/ucode/models/audit/audit_report.rb
lib/ucode/models/audit/baseline.rb            # NEW
lib/ucode/models/audit/block_summary.rb       # was AuditBlock
lib/ucode/models/audit/script_summary.rb      # NEW (was string list)
lib/ucode/models/audit/plane_summary.rb       # NEW
lib/ucode/models/audit/discrepancy.rb         # NEW
lib/ucode/models/audit/codepoint_detail.rb    # NEW
lib/ucode/models/audit/codepoint_range.rb
lib/ucode/models/audit/codepoint_set_diff.rb
lib/ucode/models/audit/audit_axis.rb
lib/ucode/models/audit/named_instance.rb
lib/ucode/models/audit/licensing.rb
lib/ucode/models/audit/metrics.rb
lib/ucode/models/audit/hinting.rb
lib/ucode/models/audit/color_capabilities.rb
lib/ucode/models/audit/variation_detail.rb
lib/ucode/models/audit/opentype_layout.rb
lib/ucode/models/audit/fs_selection_flags.rb
lib/ucode/models/audit/gasp_range.rb
lib/ucode/models/audit/embedding_type.rb
lib/ucode/models/audit/script_coverage_row.rb
lib/ucode/models/audit/script_features.rb
lib/ucode/models/audit/field_change.rb
lib/ucode/models/audit/duplicate_group.rb
lib/ucode/models/audit/library_summary.rb
lib/ucode/models/audit/audit_diff.rb
```

Specs under `spec/ucode/models/audit/` — one spec per model, all
testing `to_hash` / `from_hash` round-trip.

## Source material

Port these unchanged (just namespace swap):

- `fontisan/lib/fontisan/models/audit/codepoint_range.rb`
- `fontisan/lib/fontisan/models/audit/codepoint_set_diff.rb`
- `fontisan/lib/fontisan/models/audit/audit_axis.rb`
- `fontisan/lib/fontisan/models/audit/named_instance.rb`
- `fontisan/lib/fontisan/models/audit/licensing.rb`
- `fontisan/lib/fontisan/models/audit/metrics.rb`
- `fontisan/lib/fontisan/models/audit/hinting.rb`
- `fontisan/lib/fontisan/models/audit/color_capabilities.rb`
- `fontisan/lib/fontisan/models/audit/variation_detail.rb`
- `fontisan/lib/fontisan/models/audit/opentype_layout.rb`
- `fontisan/lib/fontisan/models/audit/fs_selection_flags.rb`
- `fontisan/lib/fontisan/models/audit/gasp_range.rb`
- `fontisan/lib/fontisan/models/audit/embedding_type.rb`
- `fontisan/lib/fontisan/models/audit/script_coverage_row.rb`
- `fontisan/lib/fontisan/models/audit/script_features.rb`
- `fontisan/lib/fontisan/models/audit/field_change.rb`
- `fontisan/lib/fontisan/models/audit/duplicate_group.rb`
- `fontisan/lib/fontisan/models/audit/library_summary.rb`
- `fontisan/lib/fontisan/models/audit/audit_diff.rb`

## Schema changes vs fontisan

Per `TODO.new/02-audit-schema-design.md`:

- `AuditReport`:
  - `fontisan_version` → `ucode_version`.
  - Drop `cldr_version` and `language_coverage`.
  - Drop `ucd_version` string → replace with `baseline` (Baseline model).
  - Drop `unicode_scripts: String[]` → replace with `scripts: ScriptSummary[]`.
  - Add `plane_summaries: PlaneSummary[]`.
  - Add `discrepancies: Discrepancy[]`.
- `AuditBlock` → renamed `BlockSummary`. Add `missing_codepoints`,
  `covered_codepoints` (verbose), `missing_count`, `coverage_percent`,
  `status`, `plane`. Drop `complete` boolean (replaced by status).
- `AuditReport` uses `key_value do map "name", to: :name end` form —
  same as fontisan. No `mapping do` (lutaml-model API; see project
  memory `lutaml_model_polymorphism_api.md`).

## lutaml-model conventions

- Parent class inherits via `< Lutaml::Model::Serializable` — never
  `include Lutaml::Model::Serializable`. See project memory
  `feedback_lutaml_model_inheritance.md`.
- Boolean attributes use `Lutaml::Model::Type::Boolean` (not Ruby
  `:boolean` — same convention as fontisan).
- Key-value serialization uses `key_value do ... end` for JSON/YAML.
  No custom `to_h`/`from_h`/`to_json`/`from_json`.
- Nested models reference other `Ucode::Models::Audit::*` classes
  directly (no string namespacing).

## Spec requirements

- One spec per model file under `spec/ucode/models/audit/`.
- Each spec:
  - Constructs an instance with realistic attribute values (no
    `nil` where the schema says non-nil).
  - Round-trips through `to_hash` → `from_hash` → field equality.
  - For collections, tests both empty and populated.
  - No `double()` — use real instances or `Struct.new`.
- `AuditReport` spec additionally verifies every documented field
  from `TODO.new/04-fontist-org-contract.md` is present.

## Acceptance

- All 27 model files exist and load via autoload chain declared in
  `lib/ucode/models/audit.rb`.
- All 27 spec files pass with no `double()` usage.
- `Ucode::Models::Audit::AuditReport.new(...)` accepts all fields
  from `02-audit-schema-design.md`.
- `AuditReport#to_hash` produces a hash matching the
  `04-fontist-org-contract.md` JSON shape (where overlapping).
- Rubocop clean.

## References

- Schema source: `TODO.new/02-audit-schema-design.md`
- Contract: `TODO.new/04-fontist-org-contract.md`
- Source files: `fontisan/lib/fontisan/models/audit/`
- lutaml-model conventions: project memory
  `lutaml_model_polymorphism_api.md`,
  `feedback_lutaml_model_inheritance.md`
- Follow-ups: `TODO.new/08-extractors-cheap-port.md` (uses these models)
