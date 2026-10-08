# Non-regression evidence (2026-10-07)

Method: `main` (commit 740ea92) and the `registry-data-layer` branch were
both built from the same aggregated artifacts and served locally;
full-page screenshots were captured with headless Chrome at 1440×2200
(light forced via the site's own `localStorage` theme preference; dark
via the same mechanism) and compared pixel-wise with ImageMagick
`compare -metric AE`.

| Page | Light AE | Dark AE | Verdict |
|------|---------:|--------:|---------|
| `/standards/` | 0 | 0 | pixel-identical |
| document page (`/cc/cc-18011-2018.html` → `/docs/cc-18011-2018.html`) | 0 | — | pixel-identical (same artifact) |
| `/404.html` | 0 | — | pixel-identical |
| `/` | 55,611 (1.76%) | 10,888 (0.34%) | explained below |

## Explained diffs on the homepage

1. **Stat number 193 → 192** — one exact cross-repo duplicate release
   (cc-adv-0707-2007, byte-identical metadata from two repos) is now
   deduplicated per the catalog contract; the count reflects real
   documents. Recorded in `registry/backfill.json`.
2. **Category card counts** change by the same −1 for the affected
   category.
3. **Same-date tie ordering** — cards sharing a publication date follow
   the catalog's canonical order ([date, edition, slug]). main's tie
   order was an artifact of GitHub search-result ordering at fetch time
   (unstable across runs); the catalog is now deterministic by design.
   Diffs are confined to the tie-group bands.

## Build reproducibility

- Cold (`rake clean && rake build`, warm download cache): 2m06s, 192
  documents, catalog schema-valid + consistent.
- Cached (immediate re-run): 1m00s, identical output.
- Fully cold (no `.cache/aggregate`, fresh fetch of 51 repos): performed
  during development; 193 aggregated documents → 192 after dedup.
