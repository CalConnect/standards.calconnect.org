import type { APIRoute } from "astro";
import { docs, catalog } from "../lib/registry";

// Atom feed derived from the contract (RFC 4287): one entry per
// document, id = permanent versioned URL, newest 50.
export const GET: APIRoute = ({ site }) => {
  const base = site!.origin;
  const esc = (s: string) =>
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  const sorted = [...docs].sort((a, b) => (b.date ?? "").localeCompare(a.date ?? "")).slice(0, 50);
  const entries = sorted.map((doc) => {
    const updated = doc.provenance.built_at ?? doc.date ?? catalog.generated_at;
    const summary = doc.abstract ? `<summary>${esc(doc.abstract)}</summary>` : "";
    const cats = [
      doc.doctype ? `<category term="${esc(doc.doctype)}"/>` : "",
      doc.stage ? `<category term="${esc(doc.stage)}"/>` : "",
    ].join("");
    const enclosures = doc.files
      .map((f) => `<link rel="enclosure" href="${esc(base + f.url)}" type="${f.media_type}" length="${f.bytes}"/>`)
      .join("");
    return [
      "<entry>",
      `<id>${esc(base + doc.url)}</id>`,
      `<title>${esc(doc.id)} — ${esc(doc.title)}</title>`,
      `<link rel="alternate" href="${esc(base + doc.url)}" type="text/html"/>`,
      doc.date ? `<published>${doc.date}</published>` : "",
      `<updated>${esc(updated)}</updated>`,
      summary,
      cats,
      enclosures,
      "</entry>",
    ].filter(Boolean).join("");
  }).join("");

  const xml = `<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <id>${esc(base)}/feed.xml</id>
  <title>${esc("CalConnect Document Registry")}</title>
  <subtitle>${esc("The CalConnect Document Registry")}</subtitle>
  <updated>${esc(catalog.generated_at)}</updated>
  <link rel="self" href="${esc(base)}/feed.xml" type="application/atom+xml"/>
  <link rel="alternate" href="${esc(base)}/" type="text/html"/>
  <author><name>${esc("CalConnect TC PUBLISH")}</name><email>tc-publish@calconnect.org</email></author>
  ${entries}
</feed>
`;
  return new Response(xml, { headers: { "Content-Type": "application/atom+xml; charset=utf-8" } });
};
