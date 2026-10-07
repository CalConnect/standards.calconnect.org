# Instance Guide — adopt the registry as an SDO

Everything an organization needs to run a Metanorma standards registry
is configuration + content + branding. Zero engine code. The engine
(catalog contract, enrichment, conformance) lives in `lib/registry/`,
`_plugins/`, `fixtures/`, `bin/` and contains no organization-specific
constants.

## 1. Prerequisites

- Ruby (Jekyll 4) + Node (Vite) — see `Gemfile` / `package.json`
- `GITHUB_TOKEN` with read access to your document repositories

## 2. Content pipeline (producer side)

Publish each document as a Metanorma repo whose releases carry the
`mn-release-metadata` block and a ZIP artifact, tagged with the
`metanorma-release` topic. Then declare discovery in
`metanorma.aggregate.yml`:

```yaml
source: github
output_dir: _site/docs        # where artifacts are extracted
file_routing: flat
cache_dir: .cache/aggregate
channels: [public]
include_drafts: true
display_categories:           # doctype → site category mapping
  - name: Standards
    slug: standards
    doctypes: [standard]
github:
  organizations: [YOUR_ORG]
  topic: metanorma-release
```

Small registries without release machinery can produce the same inputs
differently — the contract does not care. `fixtures/seed/` is a complete
hand-written producer (relaton records + artifact files); any tool that
emits `_site/docs/relaton/index.json` + `_site/docs/index.json` is a
valid producer (see `TODO.improvements/09`).

## 3. Instance configuration (`_config.yml`)

```yaml
url: https://standards.YOUR_ORG.org
registry:
  org: yourorg                       # identity
  urn_namespace: yourorg             # urn:yourorg:doc:year
  url_scheme: "/docs/:document_id/:year/"
  docs_prefix: "/docs"
  legacy_prefixes: []                # old prefixes → redirect stubs
  features:
    search: true
    atom_feed: true
    jsonld: true
    opensearch: true
    html: true                       # false → headless (data endpoints only)
  license_default: null              # NEVER invent licenses; nulls are
                                     # tracked in registry/backfill.json
```

Navigation/content pages (`_pages/`, `_data/navigation.yml`) and the
theme override pack are yours — that is the branding layer.

## 4. Build, validate, certify

```sh
bundle install && npm ci
bundle exec rake build              # fetch + enrich + render
bundle exec rake validate_schema    # catalog + search index vs published schemas
bundle exec rake validate_consistency  # Relaton projections, checksums, URLs, editions
bundle exec rspec
bundle exec rake conformance        # reference renderer AND second renderer
                                    # certified against the golden fixtures
bin/registry-conformance check _site --expect registry/catalog.json \
    --schema _data/schemas/documents.schema.json   # certify YOUR built site
```

## 5. What you get

- `/catalog.json`, `/search-index.json`, `/feed.xml`, `/opensearch.xml`
- Versioned document pages `/docs/{document_id}/{year}/` with JSON-LD,
  editions history and format buttons derived from `files[]`
- `latest` aliases, legacy redirects, category pages, search
- A data-quality backfill report (`registry/backfill.json`) — gaps are
  tracked, never fabricated

## 6. Swap or embed

- **Custom frontend**: implement the conformance profile
  (`docs/conformance-profile.md`) against `registry/catalog.json` and
  certify with `bin/registry-conformance` — `fixtures/second-renderer/`
  is a minimal Python example that passes.
- **Headless**: set `features.html: false` and embed the JSON endpoints
  elsewhere; certify with `--no-html`.

## 7. Data honesty rules

- Relaton (`bibliographic`) is canonical; projections are recomputed and
  verified on every build.
- Missing language/license/abstract stay `null` and are listed in
  `registry/backfill.json` — backfill in the source repos or via
  `license_default`, never by hand-editing the catalog.
- The catalog is rebuildable at any time: `rake enrich` is offline and
  deterministic.
