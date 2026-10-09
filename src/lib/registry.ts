// Build-time access to the registry contract and instance data.
// The catalog is produced by `rake enrich` (engine gem) before the
// Astro build; REGISTRY_DIR lets the conformance harness point the
// build at a fixture catalog instead of the live one.
import fs from "node:fs";
import path from "node:path";
import YAML from "yaml";

const root = process.cwd();
const registryDir =
  process.env.REGISTRY_DIR ?? path.join(root, "registry");

export interface FileEntry {
  format: string;
  name: string;
  media_type: string;
  bytes: number;
  sha256: string;
  url: string;
}

export interface Edition {
  edition: string | null;
  date: string | null;
  year: string | null;
  stage: string;
  slug: string;
  url: string;
  current: boolean;
}

export interface Doc {
  slug: string;
  document_id: string;
  id: string;
  title: string;
  abstract: string | null;
  doctype: string | null;
  stage: string;
  edition: string | null;
  date: string | null;
  year: string | null;
  language: string[] | null;
  license: { name?: string; url?: string; spdx?: string } | null;
  copyright: { from?: string; to?: string; owner?: string }[] | null;
  authors: { name: string; role?: string }[] | null;
  committee: string | null;
  urn: string | null;
  url: string;
  latest_url: string;
  files: FileEntry[];
  bibliographic: Record<string, unknown> | null;
  provenance: Record<string, string>;
  relations: { type: string; id: string; date?: string; edition?: string }[] | null;
  keywords: string[] | null;
  editions: Edition[];
  stage_css: string;
  doctype_class: string | null;
  display_category: string | null;
  display_category_slug: string | null;
}

export interface Category {
  title: string;
  slug: string;
  display_category_slug: string;
  description: string;
  card_color: string;
}

function readJson(p: string): unknown {
  return JSON.parse(fs.readFileSync(path.join(root, p), "utf8"));
}

const catalogRaw = readJson(path.join(
  path.relative(root, registryDir).replace(/\\/g, "/") || ".",
  "catalog.json"
)) as { org?: string; items: Doc[] };

export const catalog = catalogRaw;
export const docs: Doc[] = catalog.items;

export const navigation = YAML.parse(
  fs.readFileSync(path.join(root, "_data/navigation.yml"), "utf8")
) as { categories: Category[]; draft_stages: string[] };

export const categories = navigation.categories;
export const draftStages = navigation.draft_stages;

const siteConfig = YAML.parse(
  fs.readFileSync(path.join(root, "_config.yml"), "utf8")
) as {
  title: string;
  url: string;
  description?: string;
  registry: { publisher_name: string };
  branding?: {
    logo_light: string;
    logo_dark: string;
    copyright_name: string;
    copyright_url: string;
    footer: { community: { text: string; url: string }[]; resources: { text: string; url: string }[] };
  };
};

export const site = {
  url: siteConfig.url,
  title: siteConfig.title,
  description: siteConfig.description,
  publisher: siteConfig.registry.publisher_name,
};

const fallbackBranding = {
  logo_light: "/assets/images/logo-purple.svg",
  logo_dark: "/assets/images/logo-white.svg",
  copyright_name: siteConfig.registry.publisher_name,
  copyright_url: siteConfig.url,
  footer: { community: [] as { text: string; url: string }[], resources: [] as { text: string; url: string }[] },
};

export const branding = { ...fallbackBranding, ...(siteConfig.branding ?? {}) };

export const bySlug = (slug: string): Doc | undefined =>
  docs.find((d) => d.slug === slug);

export const docsInCategory = (slug: string): Doc[] =>
  docs
    .filter((d) => d.display_category_slug === slug)
    .sort((a, b) => (b.date ?? "").localeCompare(a.date ?? ""));

export const docsByStage = (stages: string[]): Doc[] =>
  docs.filter((d) => stages.includes(d.stage))
    .sort((a, b) => (b.date ?? "").localeCompare(a.date ?? ""));

export const currentEdition = (d: Doc): Edition | undefined =>
  d.editions.find((e) => e.current);

export const htmlFile = (d: Doc): FileEntry | undefined =>
  d.files.find((f) => f.format === "html");

export const recent = (n: number): Doc[] =>
  [...docs].filter((d) => d.date)
    .sort((a, b) => b.date!.localeCompare(a.date!))
    .slice(0, n);

export const categoryCount = (slug: string): number =>
  docs.filter((d) => d.display_category_slug === slug).length;
