# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for working with code in this repository.

## Overview

The CalConnect Standards Registry publishes CalConnect deliverables (Standards, Reports, Specifications, etc.) as an **Astro static site**, **aggregated from document-repo releases into a formal, versioned catalog contract**.

**Production URL**: https://standards.calconnect.org
**Main branch**: `main` (auto-deploys to GitHub Pages)

The registry engine (catalog contract schemas, enrichment, `registry-validate`/`registry-conformance` CLIs, golden fixtures) lives in **metanorma/standards-registry** and is consumed as a gem (Gemfile, no tag pinned yet — maintainer tags releases). This repository is the reference **instance**: `src/` forms the reference Astro renderer; CalConnect-specifics live only in `_config.yml` (`registry:` map), `metanorma.aggregate.yml`, `_data/navigation.yml`, and branding assets.

## Build Commands

```bash
bundle exec rake build              # Full pipeline: fetch → enrich → citations → Astro → finalize
bundle exec rake fetch              # Aggregate releases (network, idempotent, cached)
bundle exec rake enrich             # Build registry/catalog.json from producer outputs (no network)
bundle exec rake citations          # relaton-ts citation exports (ISO 690, BibTeX, RIS, CSL)
bundle exec rake site               # Astro + finalize only (assumes enrich done)
bundle exec rake serve              # Serve the built site locally (astro preview)
bundle exec rake clean              # Remove dist/, registry/, .artifacts/
bundle exec rake validate_schema    # Catalog vs published schema ($id v1)
bundle exec rake validate_consistency  # Recompute Relaton projections; verify files/URLs/editions
bundle exec rake validate_index[p]  # Validate any candidate catalog (generator independence)
bundle exec rake conformance        # Built site + fixture build vs registry-conformance
npm run dev                         # Vite/Astro dev server (needs registry/ to exist)
```

Aggregation requires `GITHUB_TOKEN` (read access to the org; use `export GITHUB_TOKEN=$(gh auth token)`). Aggregation config is in `metanorma.aggregate.yml`; the Rakefile passes `--output-dir` explicitly because the gem's Thor default shadows the config file's value.

## Architecture

### Pipeline

`rake build` = `metanorma-release aggregate` → `rake enrich` → `rake citations` → `astro build` → `rake finalize`

1. **Aggregate (producer)**: reads `metanorma.aggregate.yml`, discovers repos by org+topic, fetches releases, extracts files. Output: `.artifacts/docs/**`, `.artifacts/docs/index.json` (raw index incl. `source` provenance), `.artifacts/docs/relaton/index.json` (Relaton records).
2. **Enrich (engine gem, metanorma/standards-registry)**: Relaton is canonical; top-level fields are documented projections. Emits the renderer-neutral handoff: `registry/catalog.json` (schema `$id` v1, provenance, sha256/bytes/media_type per file, URN, editions model), `registry/search-index.json`, `registry/backfill.json` (honest gap list — never invent data).
3. **Citations**: `scripts/generate-citations.mjs` uses the `relaton` npm package (relaton-ts) to emit per-document ISO 690, BibTeX, RIS and CSL JSON into `registry/citations/`. Never hand-roll citation rendering.
4. **Render (Astro)**: `astro build` reads `registry/` (or `$REGISTRY_DIR`) + `_config.yml` + `_data/navigation.yml` and prerenders the homepage, category listings (`/[slug]/`), drafts/public-review/patents/search pages, versioned landing pages (`/docs/{document_id}/{year}/`), latest aliases, and root endpoints (`/catalog.json` + `.sha256`, `/search-index.json`, `/feed.xml`, `/opensearch.xml`, `/sitemap.xml`).
5. **Finalize (`rake finalize`)**: copies `.artifacts/docs/**` and `registry/citations/**` into `dist/docs/`, writes legacy `/cc/` meta-refresh redirect stubs, and runs Pagefind (`npx pagefind --site dist --root-selector main`) for the `/search/` full-text page. `rake build` then applies the catalog-count guard (fails on 0 documents or >10% shrinkage — e.g. a rate-limited aggregate run).

### The contract

- Schema `$id: https://schemas.metanorma.org/registry/documents-index/v1.json`, payload `version: 1`, additive-only within a major — bundled in the engine gem (served from the product's Pages at the $id path).
- Any conforming generator is a valid producer (`metanorma-release` is one; `fixtures/seed/` is a hand-written one).
- URLs reconstruct from the index alone (`url_scheme` tokens `:document_id`/`:year`/`:edition`); same-year editions disambiguate as `/{year}-ed{edition}/`.
- `rake validate_consistency` fails the build on projection drift, checksum mismatch, URL collisions, or edition-model violations.

### Renderer-neutrality (conformance)

`registry-conformance check SITE_DIR [--expect CATALOG] [--schema S]` (from the engine gem) validates any built site against the Registry Frontend Conformance Profile (endpoints, routes, JSON-LD, artifacts). `rake conformance` builds this instance's site AND a fixture build (engine gem's golden catalog rendered through the Astro pipeline via `REGISTRY_DIR`) and certifies both with the same suite.

### Listing Pages

Each category page is an Astro page using `src/layouts/Listing.astro`; `[slug].astro` derives routes from `_data/navigation.yml` categories and filters `docs` by `display_category_slug`. `src/lib/registry.ts` is the single build-time accessor for the catalog, navigation, and `_config.yml` site identity.

### Document Types

`standard`, `public-review`, `pending-publication`, `report`, `specification`, `administrative`, `directive`, `advisory`, `amendment`, `technical-corrigendum`, `guide`

### Styling

Tailwind CSS v4 via `@tailwindcss/vite` (see `astro.config.mjs`). Shared theme variables and navigation styles live in `src/styles/global.css` (which imports `../../_frontend/base.css`). Custom document type colors are defined there (`--color-doctype-*`).

### Key Files

- `_config.yml`: instance identity + the `registry:` map (org, urn_namespace, url_scheme, legacy_prefixes, features, license_default). Read by both the engine gem (default `site_config_path`) and `src/lib/registry.ts`.
- `metanorma.aggregate.yml`: aggregation config (orgs, topic, channels, output_dir `.artifacts/docs`, display_categories)
- `astro.config.mjs`: Astro config — `site` from `_config.yml`, Tailwind vite plugin
- `src/lib/registry.ts`: build-time catalog/navigation/site accessor (honors `REGISTRY_DIR` for fixture builds)
- `src/layouts/`: `Base.astro` (head/header/footer, `head` named slot), `Listing.astro` (category pages), `Document.astro` (landing page w/ JSON-LD + citation meta)
- `src/pages/`: static pages, `docs/[...route].astro` (landings + latest aliases), endpoint `.ts` files (catalog, search-index, feed, opensearch, sitemap)
- `public/js/`: `theme.js`, `navigation.js`, `document-list.js`, `home.js` (vanilla, loaded `is:inline`)
- `scripts/generate-citations.mjs`: relaton-ts citation exports
- `Rakefile`: pipeline + finalize + validation tasks
- Gem `standards-registry` (github: metanorma/standards-registry): the engine — Config, Projection, Urls, Enricher, Catalog, SearchIndex, Backfill, MediaTypes, CatalogRules, Consistency, Conformance, bundled schemas + fixtures

## CI/CD

GitHub Actions workflow (`.github/workflows/build_deploy.yml`):
- `build` job: `rake build` (aggregate + enrich + citations + Astro + finalize) → validations → `rspec` → `verify_links` → `report_changes` → upload `dist/` Pages artifact
- Cached aggregate state in `.cache/aggregate` for idempotent builds; the Rakefile resets the delta state when the output dir is missing
- `conformance` job: `rake conformance`
- Deploy to GitHub Pages from `main` branch only

## Development Notes

- `astro preview` (rake serve) only serves the POST-finalize `dist/` — always build via rake, never a bare `npx astro build`, or `dist/docs/` artifacts and Pagefind's index are missing
- Pagefind runs with `--root-selector main` because Metanorma HTML h1s are "Contents"/"Foreword"; per-page display titles resolve client-side from `/search-index.json`
- The full-text search page script is `is:inline` (it imports `/pagefind/pagefind.js` at runtime — Astro must not resolve it at build time)
- Dark mode uses `html.dark` class toggled by `theme.js`
- Known data issues (cross-repo duplicate releases, flat-routing file collisions, legacy docs without abstract/license) are recorded in `registry/backfill.json` on each build
