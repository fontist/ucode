# ucode implementation TODOs

Index of all implementation work. Each file in this directory is one independently
actionable chunk. Read `00-architecture.md` first — every TODO assumes its conventions.

## Setup
- [01. Gem skeleton + autoload hub + Thor CLI](01-gem-skeleton.md)
- [02. CI + quality](02-ci-and-quality.md)
- [03. Errors + Config](03-errors-and-config.md)

## Infrastructure (lifted from fontisan)
- [04. Cache layout](04-cache-layout.md)
- [05. Version resolver](05-version-resolver.md)
- [06. Fetchers](06-fetchers.md)

## Models
- [07. Model conventions + property aliases](07-model-conventions-and-property-aliases.md)
- [08. Plane, Block, Script](08-plane-block-script.md)
- [09. CodePoint core](09-codepoint-core.md)
- [10. CodePoint casing](10-codepoint-casing.md)
- [11. CodePoint bidi](11-codepoint-bidi.md)
- [12. CodePoint display](12-codepoint-display.md)
- [13. CodePoint binary](13-codepoint-binary.md)
- [14. Relationship polymorphic hierarchy](14-relationship-polymorphic.md)
- [15. UnihanEntry](15-unihan-entry.md)
- [16. Misc relationship records](16-misc-relationship-records.md)

## Parsers
- [17. Parser base + UnicodeData parser](17-parser-base-and-unicode-data.md)
- [18. Blocks/Scripts/PropertyAliases parsers](18-blocks-scripts-property-aliases-parsers.md)
- [19. NameAliases/Casing parsers](19-name-aliases-casing-parsers.md)
- [20. Bidi/CJK/Standardized parsers](20-bidi-cjk-standardized-parsers.md)
- [21. NamesList parser (state machine)](21-names-list-parser.md)
- [22. Derived + extracted parsers](22-derived-and-extracted-parsers.md)
- [23. Auxiliary parsers](23-auxiliary-parsers.md)
- [24. Unihan parsers](24-unihan-parsers.md)
- [25. Coordinator](25-coordinator.md)

## Lookup subsystem (fontisan-compatible API)
- [26. RangeEntry + Index](26-range-entry-and-index.md)
- [27. Database + DbBuilder](27-database-and-db-builder.md)
- [28. Aggregator](28-aggregator.md)

## Repo (output tree)
- [29. Repo paths + per-codepoint writer](29-repo-paths-and-codepoint-writer.md)
- [30. Aggregate writers + indexes](30-repo-aggregate-writers.md)

## Glyphs
- [31. PDF fetcher + renderer benchmark](31-glyph-pdf-fetcher-and-renderer.md)
- [32. Grid detector + cell extractor](32-glyph-grid-and-cell-extractor.md)
- [33. Glyph writer + monolith fallback](33-glyph-writer.md)

## Site
- [34. Vitepress site](34-vitepress-site.md)
- [35. CLI](35-cli.md)

## Migration + polish
- [36. fontisan migration](36-fontisan-migration.md)
- [37. Documentation + release](37-documentation-and-release.md)

## Suggested execution order

A single developer can take these in order; parallelizable groups are noted.

1. **01–03** (serial — foundation).
2. **04, 05, 06** (serial — infrastructure).
3. **07–16** (mostly parallel — models are independent; 09 is the hub for 10–15).
4. **17–24** (mostly parallel — parsers are independent; 17 is the hub).
5. **25** (serial — depends on all parsers + models).
6. **26–28** (serial — lookup subsystem; 27 depends on 25 + 26).
7. **29–30** (serial — repo writer).
8. **31–33** (serial — glyph pipeline).
9. **34, 35** (serial — site + CLI).
10. **36** (serial — fontisan migration; requires ucode feature-complete).
11. **37** (serial — polish).

## Cross-cutting rules (apply to every TODO)

- **Autoload, not require_relative**: every new class adds an `autoload` line in its
  immediate parent namespace's hub file.
- **No `to_h` / `from_h` on models**: wire shape via `key_value do … end` only.
- **No `double()` in specs**: real model instances or `Struct.new` value objects.
- **No `send` to private methods**, no `instance_variable_get/set`, no `respond_to?` for
  type checks.
- **Streaming**: parsers and Coordinator yield records one at a time, never accumulate.
- **Idempotency**: every build step is resumable; content-hash compare for write-skip.
- **Typed errors**: every raise is an `Ucode::Error` subclass with structured context.
- **`key_value do`** for all lutaml-model wire shapes (NOT `mapping do`, NOT `json do`).
