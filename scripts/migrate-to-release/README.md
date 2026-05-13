# Migration Plan: Submodule → Release-Driven Architecture

## Overview

Migrate standards.calconnect.org from 53 git submodules + monolithic compilation
to a release-driven aggregation model using `actions-mn/release` + `actions-mn/aggregate`.

**Before:** Push to doc repo → CI checks out 53 submodules → compiles 190+ documents → build → deploy (30+ min)

**After:** Push to doc repo → `site-gen` compiles + `release` publishes → `aggregate` downloads + filters → build → deploy (~5 min)

## Current Status

- **actions-mn/release**: Ready (308 tests, 18 doc types, 5 naming strategies, channel model)
- **actions-mn/aggregate**: Ready (91 tests, channel/stage filtering, ETag caching, delta dedup)
- **Repos with releases**: 3 (cc-admin-documents, cc-directive-document-requirements, cc-directive-standardization-publication)
- **Documents in releases**: 150 (600 files)
- **Local build verified**: `bundle exec rake build:from_releases` produces working site

## The Workflow Added to Each Doc Repo

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    branches: [main]
    paths: ['sources/**', 'metanorma.yml', 'metanorma.release.yml']
  workflow_dispatch:
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions-mn/site-gen@v1
      - uses: actions-mn/release@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
```

## The Aggregation CI Workflow for standards.calconnect.org

```yaml
# Uses actions-mn/aggregate to discover, download, extract, and canonicalize
- uses: actions-mn/aggregate@v1
  with:
    organizations: CalConnect
    topic: metanorma-release
    output-dir: _site/cc
    canonicalize: true
    cache-dir: .cache/aggregate
    token: ${{ secrets.GITHUB_TOKEN }}
```

This replaces the entire discover→download→extract pipeline (4 jobs → 2 jobs).

## Phase 1: Pilot — DONE

3 repos already have releases with 150 documents. Verified locally.

## Phase 2: Bulk Apply (48 remaining repos)

```bash
./scripts/migrate-to-release/02-bulk-apply.sh          # dry run
./scripts/migrate-to-release/02-bulk-apply.sh --apply   # apply
```

Rollout: CC-only (13) → CC+IETF (20) → CC+ISO (4) → Multi-flavor (5+)

## Phase 3: Seed Releases

```bash
for repo in $(gh api "search/repositories?q=topic:metanorma-release+org:CalConnect&per_page=100" \
  --jq '.items[].name'); do
  gh api "repos/CalConnect/$repo/actions/workflows/release.yml/dispatches" \
    -X POST --field ref=main 2>/dev/null
  sleep 2
done
```

## Phase 4: Migrate standards.calconnect.org CI

1. Add `03-aggregation-workflow.yml` as `build_deploy_v2.yml`
2. Run both workflows in parallel
3. Compare outputs
4. Switch to new workflow

### What stays
- Jekyll site (`_config.yml`, `_layouts/`, `_includes/`)
- Relaton templates (`src-documents/_relaton_templates/`)
- Frontend (`_frontend/`, Tailwind CSS, Vite)
- Ruby build code (`lib/calconnect/build/`)

### What gets removed
- Git submodules (`src-documents/cc-*`)
- `metanorma-*.yml` configs
- Old build-docs CI job

## Phase 5: Cleanup

- Remove git submodules
- Remove old CI workflow
- Remove `metanorma-*.yml` configs
- Update `CLAUDE.md`

## Files

```
scripts/migrate-to-release/
├── README.md                    # This plan
├── 01-release-workflow.yml      # Template for doc repo release workflow
├── 02-bulk-apply.sh             # Applies workflow + topic to all repos
└── 03-aggregation-workflow.yml  # CI for standards.calconnect.org
```
