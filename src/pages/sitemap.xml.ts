import type { APIRoute } from "astro";
import { docs, categories } from "../lib/registry";

export const GET: APIRoute = ({ site }) => {
  const base = site!.origin;
  const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
  const urls = [
    `${base}/`,
    `${base}/search/`,
    `${base}/drafts/`,
    `${base}/public-review/`,
    `${base}/patents/`,
    ...categories.map((c) => `${base}/${c.slug}/`),
  ].map((u) => `  <url><loc>${esc(u)}</loc></url>`);
  const docUrls = docs.map(
    (d) => `  <url><loc>${esc(base + d.url)}</loc>${d.date ? `<lastmod>${d.date}</lastmod>` : ""}</url>`
  );
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.join("\n")}
${docUrls.join("\n")}
</urlset>
`;
  return new Response(xml, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
};
