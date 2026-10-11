import type { APIRoute } from "astro";
import { branding, site } from "../lib/registry";

// Generated from _config.yml so the PWA identity is instance-configurable
// like the rest of branding — no static file to remember to replace.
export const GET: APIRoute = () => {
  const manifest = {
    name: site.title,
    short_name: site.publisher,
    icons: [
      { src: branding.icons.manifest_192, sizes: "192x192", type: "image/png", purpose: "maskable" },
      { src: branding.icons.manifest_512, sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
    theme_color: "#ffffff",
    background_color: "#ffffff",
    display: "standalone",
  };
  return new Response(JSON.stringify(manifest, null, 2), {
    headers: { "Content-Type": "application/manifest+json; charset=utf-8" },
  });
};
