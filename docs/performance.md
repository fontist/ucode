# Performance

Measured on dev hardware via `benchmark/full_pipeline.rb`. Numbers are
indicative, not authoritative — they vary with disk speed, network
conditions, and CPU.

## Targets

| Phase                       | Cold cache  | Warm cache |
|-----------------------------|-------------|------------|
| Full pipeline (fetch+parse) | < 10 min    | < 5 min    |
| SQLite `lookup_block`       | < 1 ms      | < 1 ms     |

## Profiling

```sh
bundle exec ruby benchmark/full_pipeline.rb --version=17.0.0
```

Re-run with `--force` to measure cold-cache paths.

## Hot paths

- **Coordinator enrichment** — `Coordinator#enrich` runs once per
  codepoint (~160k invocations for Unicode 17). Each invocation does
  several `bsearch` lookups into the sorted indices. Profile here if
  parse phase is slow.
- **CodepointWriter** — one file write per codepoint. The worker pool
  parallelizes this; bump `Ucode.configuration.parallel_workers` if
  disk is the bottleneck.
- **AggregateWriter#flush** — runs after the streaming pass. Most time
  is in `write_relationships` (one file per source kind) and
  `write_blocks_index` (single big JSON dump).
- **Glyphs::Writer#write_all** — one `pdftocairo` invocation per PDF
  page. Bumping `parallel_workers` helps here too.

## Memory

The Coordinator streams — peak memory is the Indices struct (~10 MB)
plus one CodePoint in flight. The Repo writers are similarly streaming.
The AggregateWriter's accumulators (`@block_codepoint_ids`,
`@names_index`, `@labels_index`) grow linearly with codepoint count;
expect ~30 MB resident for the full Unicode 17 dataset.

The CLI's `parse` command never holds more than one CodePoint outside
the AggregateWriter's accumulators.

## Search index size

`output/index/search.json` for Unicode 17 is ~5 MB raw JSON (160k
codepoints × ~30 bytes). Gzipped for HTTP transport: ~1.5 MB. MiniSearch
decompresses lazily on the client; first-paint is unaffected.
