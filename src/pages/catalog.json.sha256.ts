// Integrity sidecar: sha256 of the served catalog payload.
import type { APIRoute } from "astro";
import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";

export const GET: APIRoute = () => {
  const dir = process.env.REGISTRY_DIR ?? path.join(process.cwd(), "registry");
  const body = fs.readFileSync(path.join(dir, "catalog.json"));
  const digest = createHash("sha256").update(body).digest("hex");
  return new Response(`${digest}  catalog.json\n`, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
};
