// Byte-faithful copy of the engine handoff (the contract payload).
import type { APIRoute } from "astro";
import fs from "node:fs";
import path from "node:path";

export const GET: APIRoute = () => {
  const dir = process.env.REGISTRY_DIR ?? path.join(process.cwd(), "registry");
  const body = fs.readFileSync(path.join(dir, "catalog.json"));
  return new Response(new Uint8Array(body), {
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
};
