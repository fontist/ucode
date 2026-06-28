# 16 — archive-public: three sync workflows (GHA)

## Goal

Add the three GitHub Actions workflows that sync `fontist-archive-public`
from its three upstream sources:

1. `sync-private.yml` — pulls from `fontist-archive-private` on push
2. `sync-ucode.yml` — pulls from `fontist/ucode` publish workflow
3. `sync-panglyph.yml` — pulls from `fontist/panglyph` tag pushes

Each writes to a disjoint directory (`coverage/`, `unicode/`, `panglyph/`),
so concurrent runs don't conflict.

## Why this is a separate TODO

The directory placeholders exist (committed in the
`audit/add-unicode-and-panglyph-dirs` branch). The sync workflows are
the actual machinery. Without them, the directories stay empty.

## Scope

### sync-private.yml

```yaml
name: Sync from fontist-archive-private

on:
  repository_dispatch:
    types: [archive-private-updated]
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Clone private (read-only deploy key)
        env:
          SSH_KEY: ${{ secrets.ARCHIVE_PRIVATE_DEPLOY_KEY }}
        run: |
          mkdir -p ~/.ssh && echo "$SSH_KEY" > ~/.ssh/id_ed25519 && chmod 600 ~/.ssh/id_ed25519
          git clone --depth 1 git@github.com:fontist/fontist-archive-private.git /tmp/private
      - name: Sync coverage/
        run: |
          rm -rf coverage
          cp -r /tmp/private/coverage .
      - name: Sync woff/ (open-license only)
        run: |
          rm -rf woff
          mkdir -p woff
          for d in /tmp/private/woff/*; do
            base=$(basename "$d")
            [ "$base" != "macos" ] && cp -r "$d" "woff/"
          done
      - name: Sync fonts.json + font-metadata.json
        run: cp /tmp/private/fonts.json /tmp/private/font-metadata.json . || true
      - name: Commit
        run: |
          git config user.email "archive-bot@fontist.org"
          git config user.name "archive-bot"
          git add -A
          git diff --quiet HEAD || git commit -m "Sync from fontist-archive-private @ $(date -u +%Y-%m-%dT%H:%M:%SZ)"
          git push
```

### sync-ucode.yml

```yaml
name: Sync from fontist/ucode

on:
  workflow_run:
    workflows: [publish-unicode-archive]
    types: [completed]
    branches: [main]
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    steps:
      - uses: actions/checkout@v4
      - name: Download ucode artifacts
        uses: actions/github-script@v7
        with:
          script: |
            const runId = context.payload.workflow_run.id
            const artifacts = await github.rest.actions.listWorkflowRunArtifacts({
              owner: 'fontist', repo: 'ucode', run_id: runId
            })
            // download unicode-block-feed.tar.gz + universal-glyph-set.tar.gz
            // ...
      - name: Sync unicode/
        run: |
          rm -rf unicode/block-feed unicode/universal-glyph-set
          mkdir -p unicode/block-feed unicode/universal-glyph-set
          tar xzf /tmp/block-feed.tar.gz -C unicode/block-feed
          tar xzf /tmp/universal-glyph-set.tar.gz -C unicode/universal-glyph-set
      - name: Commit
        run: |
          git config user.email "archive-bot@fontist.org"
          git config user.name "archive-bot"
          git add -A unicode/
          git diff --quiet HEAD -- unicode/ || git commit -m "Sync unicode/ from fontist/ucode"
          git push
```

### sync-panglyph.yml

```yaml
name: Sync from fontist/panglyph

on:
  repository_dispatch:
    types: [panglyph-released]
  workflow_dispatch:
    inputs:
      version:
        description: 'panglyph version (e.g. 17.0.0)'
        required: true

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Download panglyph release
        env:
          GH_TOKEN: ${{ secrets.ARCHIVE_PUBLIC_BOT_TOKEN }}
        run: |
          VERSION="${{ inputs.version || github.event.client_payload.version }}"
          gh release download "v${VERSION}" \
            --repo fontist/panglyph \
            --pattern "panglyph-unicode*.{ttf,woff2,otf}" \
            --pattern "coverage-report.json" \
            --pattern "source-manifest.json" \
            --dir "/tmp/v${VERSION}"
      - name: Sync panglyph/
        run: |
          mkdir -p "panglyph/v${VERSION}"
          cp /tmp/v${VERSION}/* "panglyph/v${VERSION}/"
          # Update top-level manifest.json (script in bin/update-panglyph-manifest.rb)
          ruby bin/update-panglyph-manifest.rb "${VERSION}"
      - name: Commit
        run: |
          git config user.email "archive-bot@fontist.org"
          git config user.name "archive-bot"
          git add -A panglyph/
          git diff --quiet HEAD -- panglyph/ || git commit -m "Sync panglyph v${VERSION}"
          git push
```

## Acceptance

- [ ] All three workflows exist + are syntactically valid YAML
- [ ] Each writes to a disjoint directory
- [ ] Manual dispatch works (`workflow_dispatch`)
- [ ] Trigger-based dispatch works (`repository_dispatch` / `workflow_run`)
- [ ] Bot commits identify as `archive-bot@fontist.org`

## References

- [TODO.full/09](09-archive-public-structure.md) — target structure
- [TODO.full/04](04-panglyph-publish-pipeline.md) — panglyph publish trigger
- [TODO.new/41](../TODO.new/41-ucode-unicode-archive-bridge.md) — ucode publish trigger
