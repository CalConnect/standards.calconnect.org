import type { APIRoute } from "astro";
import { docs } from "../lib/registry";

export const GET: APIRoute = ({ site }) => {
  const base = site!.origin;
  const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
  const urls = [
    `${base}/`,
    `${base}/search/`,
    ...new Set(docs.map((d) => d.display_category_slug).filter(Boolean) as string[]).values(),
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
