// Registry instance: static build over the registry contract.
// The catalog (registry/catalog.json) is produced by `rake enrich`;
// artifacts land in .artifacts/docs and are finalized into dist/ by
// `rake finalize` (TODO.improvements/11.3).
import fs from "node:fs";
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import YAML from "yaml";

const siteConfig = YAML.parse(fs.readFileSync("_config.yml", "utf8"));

const basePath = (siteConfig.registry?.base_path ?? "").replace(/\/$/, "");

export default defineConfig({
  site: siteConfig.url,
  ...(basePath ? { base: basePath } : {}),
  vite: { plugins: [tailwindcss()] },
});
