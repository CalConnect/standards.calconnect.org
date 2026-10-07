#!/usr/bin/env python3
"""A minimal, NON-Jekyll registry renderer (Python stdlib only).

Consumes exactly the renderer-neutral handoff — registry/catalog.json,
registry/search-index.json and the artifact files located by files[].url
— and emits a conformant static site (docs/conformance-profile.md v1):
the four data endpoints, versioned landing pages with JSON-LD and links
to every artifact, latest-alias redirects, and the artifacts themselves.

Certified by the same registry-conformance suite as the reference
Jekyll renderer:
    python3 fixtures/second-renderer/render.py \
        --registry <handoff-dir> --files <artifact-files-dir> --out <site-dir>
    bin/registry-conformance check <site-dir> --expect <handoff-dir>/catalog.json
"""

import argparse
import html
import json
import shutil
from pathlib import Path
from xml.sax.saxutils import escape as xesc


def build(registry_dir: Path, files_dir: Path, out_dir: Path) -> None:
    catalog = json.loads((registry_dir / "catalog.json").read_text())
    search = json.loads((registry_dir / "search-index.json").read_text())
    org = catalog.get("org", "registry")
    site_url = f"https://standards.{org}.example"

    out = out_dir
    out.mkdir(parents=True, exist_ok=True)

    # Endpoints: byte-faithful copies of the handoff
    shutil.copyfile(registry_dir / "catalog.json", out / "catalog.json")
    shutil.copyfile(registry_dir / "search-index.json", out / "search-index.json")
    (out / "feed.xml").write_text(render_feed(catalog, site_url))
    (out / "opensearch.xml").write_text(render_opensearch(org, site_url))

    # Artifacts: placed at their contract urls
    for item in catalog["items"]:
        for f in item["files"]:
            dest = out / f["url"].lstrip("/")
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(files_dir / f["url"].removeprefix("/docs/"), dest)

    # Versioned landing pages + latest aliases
    for item in catalog["items"]:
        page = render_landing(item, site_url)
        landing = out / item["url"].lstrip("/") / "index.html"
        landing.parent.mkdir(parents=True, exist_ok=True)
        landing.write_text(page)

        current = next(
            (e for e in item["editions"] if e["current"] and e["url"] == item["url"]),
            None,
        )
        if current:
            alias = out / item["latest_url"].lstrip("/") / "index.html"
            alias.parent.mkdir(parents=True, exist_ok=True)
            alias.write_text(render_redirect(item["url"], site_url))


def render_landing(item: dict, site_url: str) -> str:
    url = f"{site_url}{item['url']}"
    encodings = ",\n".join(
        json.dumps(
            {
                "@type": "MediaObject",
                "encodingFormat": f["media_type"],
                "contentUrl": f"{site_url}{f['url']}",
                "name": f.get("name", ""),
            }
        )
        for f in item["files"]
    )
    jsonld = json.dumps(
        {
            "@context": "https://schema.org",
            "@type": "TechArticle",
            "@id": url,
            "identifier": item["id"],
            "name": item["title"],
            "url": url,
            "datePublished": item["date"],
            "encoding": json.loads(f"[{encodings}]") if encodings else [],
        },
        ensure_ascii=False,
    )
    links = "".join(
        f'<a class="dl-btn dl-{xesc(f["format"])}" href="{xesc(f["url"])}">{xesc(f["format"].upper())}</a> '
        for f in item["files"]
    )
    editions = "".join(
        f'<li class="doc-edition{" current" if e["current"] else ""}">'
        + (
            f'<span class="doc-edition-id">{xesc(e["edition"] or "1")} ({xesc(e["year"] or "")}) — this edition</span>'
            if e["url"] == item["url"]
            else f'<a class="doc-edition-id" href="{xesc(e["url"])}">{xesc(e["edition"] or "1")} ({xesc(e["year"] or "")})</a>'
        )
        + "</li>"
        for e in item["editions"]
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{html.escape(item["id"])}</title>
<link rel="canonical" href="{xesc(url)}">
<script type="application/ld+json">{jsonld}</script>
</head>
<body>
<main>
<h1>{html.escape(item["id"])}</h1>
<p>{html.escape(item["title"])}</p>
<p>{html.escape(item["doctype"] or "")} · Edition {html.escape(item["edition"] or "1")} · {html.escape(item["date"] or "")} · {html.escape(item["stage"])}</p>
{f'<p>{html.escape(item["abstract"])}</p>' if item["abstract"] else ""}
<p>URN: <code>{html.escape(item["urn"] or "—")}</code></p>
<div class="doc-downloads">{links}</div>
<section class="doc-editions"><h2>Editions</h2><ul class="doc-editions-list">{editions}</ul>
<p><a href="{xesc(item["latest_url"])}">Latest edition</a></p></section>
</main>
</body>
</html>
"""


def render_redirect(target: str, site_url: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>{xesc(target)}</title>
<link rel="canonical" href="{xesc(target)}">
<meta http-equiv="refresh" content="0; url={xesc(target)}"></head>
<body><p>This document has moved to <a href="{xesc(target)}">{xesc(site_url + target)}</a>.</p></body>
</html>
"""


def render_feed(catalog: dict, site_url: str) -> str:
    ns = "http://www.w3.org/2005/Atom"
    entries = []
    for item in sorted(catalog["items"], key=lambda i: i["date"] or "", reverse=True)[:50]:
        updated = item["provenance"].get("built_at") or item["date"] or ""
        abstract = (
            f"<summary>{xesc(item['abstract'])}</summary>" if item["abstract"] else ""
        )
        enclosures = "".join(
            f'<link rel="enclosure" href="{xesc(site_url + f["url"])}" '
            f'type="{xesc(f["media_type"])}" length="{f["bytes"]}"/>'
            for f in item["files"]
        )
        entries.append(
            f"<entry><id>{xesc(site_url + item['url'])}</id>"
            f"<title>{xesc(item['id'])} — {xesc(item['title'])}</title>"
            f'<link rel="alternate" href="{xesc(site_url + item["url"])}" type="text/html"/>'
            f"<updated>{xesc(updated)}</updated>{abstract}{enclosures}</entry>"
        )
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        f'<feed xmlns="{ns}"><id>{xesc(site_url)}/feed.xml</id>'
        f"<title>{xesc(org_title(catalog))}</title>"
        f"<updated>{xesc(catalog.get('generated_at', ''))}</updated>"
        f'<link rel="self" href="{xesc(site_url)}/feed.xml" type="application/atom+xml"/>'
        f"<author><name>{xesc(org_title(catalog))}</name></author>"
        + "".join(entries)
        + "</feed>\n"
    )


def org_title(catalog: dict) -> str:
    return f"{catalog.get('org', 'Registry').capitalize()} Document Registry"


def render_opensearch(org: str, site_url: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">'
        f"<ShortName>{xesc(org_title({'org': org}))}</ShortName>"
        f"<Description>Search {xesc(org_title({'org': org}))} documents</Description>"
        '<Url type="text/html" method="get" template="'
        f"{xesc(site_url)}/?q={{searchTerms}}\"/></OpenSearchDescription>\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, help="handoff dir (catalog + search index)")
    parser.add_argument("--files", required=True, help="producer artifact files dir")
    parser.add_argument("--out", required=True, help="site output dir")
    args = parser.parse_args()
    build(Path(args.registry), Path(args.files), Path(args.out))
    print(f"second renderer: site written to {args.out}")


if __name__ == "__main__":
    main()
