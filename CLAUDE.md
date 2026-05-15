# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The CalConnect Standards Registry publishes CalConnect deliverables (Standards, Reports, Specifications, etc.) as a Jekyll site with a single Vite-powered CSS/JS pipeline.

**Production URL**: https://standards.calconnect.org
**Main branch**: `main` (auto-deploys to GitHub Pages)

## Build Commands

```bash
bundle exec rake build    # Full pipeline: aggregate releases → Jekyll build
bundle exec rake fetch    # Aggregate releases only (idempotent, uses cache)
bundle exec rake jekyll   # Jekyll build only (assumes fetch done)
bundle exec rake serve    # Serve the built site locally
bundle exec rake clean    # Remove _site/
```

All aggregation config is in `metanorma.aggregate.yml`. The CLI auto-detects this file.

### Vite/Frontend Commands

```bash
npm run dev                  # Vite dev server (watch mode)
npm run build                # Vite production build
```

## Architecture

### Build Pipeline

`rake build` = `metanorma-release aggregate` → Jekyll build

1. **Aggregate**: `metanorma-release aggregate` reads `metanorma.aggregate.yml`, discovers repos by org+topic, fetches releases, extracts files, enriches with Relaton. Output: `_site/cc/` with document files, `index.json`, and `relaton/index.json`
2. **Jekyll build**: Reads `_site/cc/relaton/index.json`, renders all pages

Idempotent: re-running `rake fetch` uses cached delta state (`.cache/aggregate/`) to skip unchanged repos.

### Config-driven

All aggregation config lives in `metanorma.aggregate.yml`. The Rakefile is a thin wrapper — just calls the CLI and Jekyll.

### Doc-Type Listing Pages

Each doc-type page is a Jekyll page in `_pages/` (e.g., `_pages/standard.html`) using the `doc-type` layout. The layout reads `site.data.documents.items | where: "doctype", page.doctype` via Liquid and renders document cards with search/filter/sort.

**Key files:**
- `_layouts/doc-type.html` — layout with hero, search, toolbar, document cards
- `_pages/{doctype}.html` — one source file per doc type (just front matter)

### Document Types

`standard`, `public-review`, `pending-publication`, `report`, `specification`, `administrative`, `directive`, `advisory`, `amendment`, `technical-corrigendum`, `guide`

### Theme

Uses the `jekyll-calconnect-theme` gem. Frontend styling uses Tailwind CSS v4 with Vite. Shared theme variables and navigation styles live in `_frontend/base.css`.

### Key Files

- `_config.yml`: Jekyll configuration (theme, collections, `keep_files: [cc, relaton]`)
- `_layouts/`: `doc-type.html` (listing pages), `document.html` (individual docs), `page.html`, `default.html`
- `_includes/`: `header.html`, `footer.html` (shared across all pages)
- `_frontend/entrypoints/application.css`: Single Tailwind CSS entrypoint (includes doc-type page styles)
- `_frontend/entrypoints/application.js`: Single JS entrypoint (includes theme, navigation, document-list)
- `_frontend/base.css`: Shared theme variables, colors, navigation styles
- `metanorma.aggregate.yml`: Aggregation config (orgs, topic, file routing, cache)
- `Rakefile`: Thin wrapper — calls CLI + Jekyll

## CI/CD

GitHub Actions workflow (`.github/workflows/build_deploy.yml`):
- Single `build` job: `bundle exec rake build` (aggregate + Jekyll)
- Cached aggregate state in `.cache/aggregate` for idempotent builds
- Deploy to GitHub Pages from `main` branch only

## Development Notes

- Jekyll uses Vite via `jekyll-vite` plugin; Tailwind CSS processes files during Jekyll build
- `_site/cc/` and `_site/relaton/` are preserved across Jekyll rebuilds via `keep_files`
- Dark mode uses `html.dark` class toggled by `theme.js` (loaded via Vite `application.js`)
- Custom document type colors are defined in `_frontend/base.css` (`--color-doctype-*`)
