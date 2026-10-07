# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for working with code in this repository.

## Overview

The CalConnect Standards Registry publishes CalConnect deliverables (Standards, Reports, Specifications, etc.) as a Jekyll site with a single Vite-powered CSS/JS pipeline, **aggregated from document-repo releases into a formal, versioned catalog contract**.

**Production URL**: https://standards.calconnect.org
**Main branch**: `main` (auto-deploys to GitHub Pages)

The registry engine (catalog contract schemas, enrichment, `registry-validate`/`registry-conformance` CLIs, golden fixtures, certified non-Jekyll second renderer) lives in **metanorma/standards-registry** and is consumed as a gem (Gemfile, no tag pinned yet — maintainer tags releases). This repository is the reference **instance**: `_plugins/registry_catalog.rb` + `_layouts/` form the reference Jekyll renderer; CalConnect-specifics live only in `_config.yml` (`registry:` map), `metanorma.aggregate.yml`, navigation/content and branding.

## Build Commands

```bash
bundle exec rake build              # Full pipeline: fetch → enrich → Jekyll
bundle exec rake fetch              # Aggregate releases (network, idempotent, cached)
bundle exec rake enrich             # Build registry/catalog.json from producer outputs (no network)
bundle exec rake jekyll             # Vite + Jekyll only (assumes enrich done)
bundle exec rake serve              # Serve the built site locally
bundle exec rake clean              # Remove _site/ and registry/
bundle exec rake validate_schema    # Catalog vs published schema ($id v1)
bundle exec rake validate_consistency  # Recompute Relaton projections; verify files/URLs/editions
bundle exec rake validate_index[p]  # Validate any candidate catalog (generator independence)
bundle exec rake conformance        # Reference renderer vs golden fixtures + checker
```

Aggregation requires `GITHUB_TOKEN` (read access to the org). Aggregation config is in `metanorma.aggregate.yml`; the Rakefile passes `--output-dir` explicitly because the gem's Thor default shadows the config file's value.

## Architecture

### Pipeline

`rake build` = `metanorma-release aggregate` → `rake enrich` → Jekyll build

1. **Aggregate (producer)**: reads `metanorma.aggregate.yml`, discovers repos by org+topic, fetches releases, extracts files, enriches with Relaton. Output: `_site/docs/**`, `_site/docs/index.json` (raw index incl. `source` provenance), `_site/docs/relaton/index.json` (Relaton records).
2. **Enrich (engine gem, metanorma/standards-registry): Relaton is canonical; top-level fields are documented projections. Emits the renderer-neutral handoff: `registry/catalog.json` (schema `$id` v1, provenance, sha256/bytes/media_type per file, URN, editions model), `registry/search-index.json`, `registry/backfill.json` (honest gap list — never invent data).
3. **Render (reference renderer)**: `_plugins/registry_catalog.rb` reads `registry/` only (never `_data/`), serves `/catalog.json` + `/search-index.json` at root, and generates versioned landing pages (`/docs/{document_id}/{year}/`), latest aliases (`/docs/{document_id}/`), legacy `/cc/` redirects, plus `/feed.xml` (Atom) and `/opensearch.xml`.

### The contract

- Schema `$id: https://schemas.metanorma.org/registry/documents-index/v1.json`, payload `version: 1`, additive-only within a major — bundled in the engine gem (served from the product's Pages at the $id path).
- Any conforming generator is a valid producer (`metanorma-release` is one; `fixtures/seed/` is a hand-written one).
- URLs reconstruct from the index alone (`url_scheme` tokens `:document_id`/`:year`/`:edition`); same-year editions disambiguate as `/{year}-ed{edition}/`.
- `rake validate_consistency` fails the build on projection drift, checksum mismatch, URL collisions, or edition-model violations.

### Renderer-neutrality (conformance)

`registry-conformance check SITE_DIR [--expect CATALOG] [--schema S] [--no-html]` (from the engine gem) validates any built site against the Registry Frontend Conformance Profile (endpoints, routes, JSON-LD, artifacts). `rake conformance` builds the reference renderer against the engine gem's golden fixtures AND certifies the gem's Python second renderer with the same suite.

### Doc-Type Listing Pages

Each doc-type page is a Jekyll page in `_pages/` using the `doc-type` layout. The layout filters `site.data.registry_catalog.items` and renders document cards linking to canonical landing URLs with format buttons derived from `files[]`.

### Document Types

`standard`, `public-review`, `pending-publication`, `report`, `specification`, `administrative`, `directive`, `advisory`, `amendment`, `technical-corrigendum`, `guide`

### Theme

Uses the `jekyll-calconnect-theme` gem. Frontend styling uses Tailwind CSS v4 with Vite. Shared theme variables and navigation styles live in `_frontend/base.css`.

### Key Files

- `_config.yml`: Jekyll config + the `registry:` instance map (org, urn_namespace, url_scheme, legacy_prefixes, features, license_default)
- `metanorma.aggregate.yml`: aggregation config (orgs, topic, channels, output_dir, display_categories)
- Gem `standards-registry` (github: metanorma/standards-registry): the engine — Config, Projection, Urls, Enricher, Catalog, SearchIndex, Backfill, MediaTypes, CatalogRules, Consistency, Conformance, bundled schemas + fixtures
- `_plugins/registry_catalog.rb`: renderer bridge (reads `registry/`, generates routes/endpoints)
- `_layouts/`: `doc-type.html` (listing), `document.html` (landing page w/ JSON-LD), `redirect.html` (meta-refresh), `page.html`, `default.html`
- `_pages/feed.xml`, `_pages/opensearch.xml`: catalog-derived endpoints
- `_frontend/js/home.js`: fetches `/search-index.json` lazily; category pages work without JS
- `Rakefile`: pipeline + validation tasks

## CI/CD

GitHub Actions workflow (`.github/workflows/build_deploy.yml`):
- Single `build` job: `rake build` (aggregate + enrich + Jekyll) → validations → verify non-empty catalog → upload Pages artifact
- Cached aggregate state in `.cache/aggregate` for idempotent builds; the Rakefile resets the delta state when the output dir is missing
- `conformance` job: `rake conformance`
- Deploy to GitHub Pages from `main` branch only

## Development Notes

- Jekyll uses Vite via `jekyll-vite`; Tailwind CSS processes files during Jekyll build
- `keep_files: [docs]` preserves aggregator output across Jekyll rebuilds; `registry/` is excluded from copying (the plugin serves it at root)
- Dark mode uses `html.dark` class toggled by `theme.js`
- Custom document type colors are defined in `_frontend/base.css` (`--color-doctype-*`)
- Known data issues (cross-repo duplicate releases, flat-routing file collisions, legacy docs without abstract/license) are recorded in `registry/backfill.json` on each build
