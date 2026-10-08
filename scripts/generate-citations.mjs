#!/usr/bin/env node
// Generates per-document citation exports from the registry contract,
// using the relaton-ts renderers (toIso690 / toBibtex / toRis /
// toCslJson) — the ecosystem's tested citation implementations.
//
//   node bin/generate-citations.mjs [--catalog registry/catalog.json]
//                                   [--out registry/citations]
//
// Output files land in the renderer-neutral handoff; the reference
// renderer serves them at /docs/{slug}.{iso690.txt,bib,ris,csl.json}.

import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { toIso690, toBibtex, toRis, toCslJson } from "relaton";

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
}

const catalogPath = arg("--catalog", "registry/catalog.json");
const outDir = arg("--out", "registry/citations");

const catalog = JSON.parse(await readFile(catalogPath, "utf8"));
await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });

let written = 0;
for (const item of catalog.items) {
  const bib = item.bibliographic;
  const exports = {
    "iso690.txt": bib ? toIso690(bib) : `${item.id}, ${item.title}.`,
    "bib": bib ? toBibtex(bib) : null,
    "ris": bib ? toRis(bib) : null,
    "csl.json": bib ? toCslJson(bib) : null,
  };
  for (const [ext, content] of Object.entries(exports)) {
    if (!content) continue;
    await writeFile(path.join(outDir, `${item.slug}.${ext}`), content + "\n");
    written += 1;
  }
}
console.log(`OK: ${written} citation files for ${catalog.items.length} documents in ${outDir}`);
