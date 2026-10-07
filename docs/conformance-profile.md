# Registry Frontend Conformance Profile — v1

Normative requirements for a **registry frontend**: the component that
turns the renderer-neutral handoff (`registry/catalog.json`,
`registry/search-index.json`, plus the producer's artifact files) into a
served site. The Jekyll theme in this repository is the **reference
implementation**; any stack that satisfies this profile is an equally
valid renderer (`fixtures/second-renderer/` ships a Python example).
Certification is mechanical:

```
bin/registry-conformance check <built-site-dir> \
    [--expect <producer-catalog.json>] \
    [--schema <_data/schemas/documents.schema.json>] [--no-html]
```

Exit code 0 = conformant. The checker is the profile, executable.

## 1. Inputs

A conformant renderer reads **only**:

- `registry/catalog.json` — the catalog contract
  (`https://schemas.metanorma.org/registry/documents-index/v1.json`)
- `registry/search-index.json` — the derived search view
  (`https://schemas.metanorma.org/registry/search-index/v1.json`)
- the artifact files, located by `files[].url` under the instance's
  `docs_prefix`

No producer API, no `_data/`, no Jekyll paths, no instance code crosses
this boundary.

## 2. Endpoints (always required, including headless)

| Route | Requirement |
|---|---|
| `/catalog.json` | byte-faithful copy of the handoff catalog; MUST validate against the catalog schema; with `--expect`, MUST match the producer's copy (urls + count) |
| `/search-index.json` | byte-faithful copy; every `documents[].url` MUST be a catalog item url |
| `/feed.xml` | well-formed XML; Atom (RFC 4287); feed `id` present; every entry `id` MUST resolve (scheme-relative) to a catalog item url |
| `/opensearch.xml` | well-formed XML; `OpenSearchDescription` with a `Url@template` containing `{searchTerms}` |

## 3. Routes (required when the renderer emits HTML; skipped under `--no-html`)

| Route | Requirement |
|---|---|
| `item.url` (versioned landing, e.g. `/docs/{document_id}/{year}/`) | exists, references the item's `id`, links **every** `files[].url`, and carries parseable JSON-LD with an `@type` (reference renderer: `TechArticle`) |
| `item.latest_url` (`/docs/{document_id}/`) | exists and redirects (statically: meta refresh) to the current edition's `item.url`, with `rel="canonical"` pointing at the target |
| `files[].url` | every artifact exists at its declared url |

HTML routes are optional for **headless** instances
(`registry.features.html: false`): a headless renderer serves §2 only
and is certified with `--no-html`.

## 4. Semantics and behaviors (reference-renderer contract)

The profile checks mechanically above; a production renderer additionally
SHOULD provide, per the instance's `registry.features` map: format
buttons derived from `files[]` (not hardcoded), category and stage
filtering, client-side search over the fetched `/search-index.json` with
a no-JS fallback, JSON-LD on category pages, and head `link` tags for the
feed and OpenSearch description. Anything beyond this profile is
renderer-specific and not portable — instances opting into extras accept
the coupling.

## 5. Certification in CI

```
rake conformance   # reference renderer AND second renderer vs golden fixtures
```

Both renderers pass the same suite; neither holds a private advantage.
