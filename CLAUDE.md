# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

The CalConnect Standards Registry publishes CalConnect deliverables (Standards, Reports, Specifications, etc.) as a Jekyll site. Documents are compiled via Metanorma and stored as Git submodules in `src-documents/`.

**Production URL**: https://standards.calconnect.org
**Main branch**: `main` (auto-deploys to GitHub Pages)

## Build Commands

```bash
# Install all dependencies and build everything
make prep                    # Checkout submodules + install Ruby + Node deps
make build-all-parallel      # Jekyll + all document types in parallel

# Individual stages
make jekyll                  # Build Jekyll site only → _site/
make build                   # Build all Metanorma documents (serial)
make build-parallel          # Build all Metanorma documents (parallel)
make build-relaton           # Build Relaton bibliography index files

# Serve locally
make serve                   # Jekyll serve (note: doesn't rebuild docs first)

# Serve the built _site/ (recommended)
npx serve _site
```

### Vite/Frontend Commands

```bash
npm run dev                  # Vite dev server (watch mode)
npm run build                # Vite production build
```

## Architecture

### Two-Stage Build Process

1. **Jekyll stage** (`_config.yml`, `_layouts/`, `_includes/`, `_pages/`): Builds the static site shell
2. **Metanorma stage** (`src-documents/`, `metanorma-*.yml`): Compiles document submodules into HTML/PDF/RXL

Documents are added/removed via git submodules in `src-documents/`, then the corresponding `metanorma-*.yml` files are repopulated:

```bash
make repopulate-metanorma-yamls-parallel
```

### Document Types

Defined in `Makefile` (`DOC_TYPES`): `administrative`, `standard`, `report`, `directive`, `specification`, `advisory`, `amendment`, `technical-corrigendum`, `public-review`, `pending-publication`

### Theme

Uses the `calconnect-theme` gem (sibling repo at `../calconnect-theme`). Frontend styling migrated from Materialize to Tailwind CSS v4 with Vite.

### Key Files

- `_config.yml`: Jekyll configuration (theme, collections, plugins)
- `_layouts/`: Page templates (`document.html`, `page.html`, `default.html`, `toc.html`)
- `_includes/`: Reusable components (`header.html`, `footer.html`, `toc-sidebar.html`)
- `src-documents/`: Git submodules containing CalConnect document sources
- `src-documents/metanorma-*.yml`: Metanorma config per document type
- `_frontend/entrypoints/application.css`: Tailwind CSS entrypoint with custom theme variables

### Relaton/Bibliography

Relaton templates in `src-documents/_relaton_templates/` render document metadata via Liquid templates. Outputs: `relaton/yaml/index.yaml` and `relaton/rxl/index.rxl`.

## CI/CD

GitHub Actions workflow (`.github/workflows/build_deploy.yml`):
- `build-site`: Jekyll build, cached
- `build-docs`: Metanorma site generate per doc type (runs in `metanorma/metanorma` Docker container), cached
- `check-artifacts`: Merges all artifacts, runs `make build-relaton`
- `deploy`: Deploys to GitHub Pages from `main` branch only

## Development Notes

- Jekyll uses Vite via `jekyll-vite` plugin; Tailwind CSS processes files during Jekyll build
- Document artifact canonicalization happens via `scripts/canonicalize-document-paths` to normalize URLs
- The `_frontend/` directory uses Tailwind CSS v4 with `@tailwindcss/postcss` plugin
- Custom document type colors are defined in `application.css` (`--color-doctype-*`)
