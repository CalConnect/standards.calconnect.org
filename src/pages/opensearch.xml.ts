import type { APIRoute } from "astro";
import { withBase } from "../lib/registry";

export const GET: APIRoute = ({ site }) => {
  const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const title = "CalConnect Document Registry";
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
  <ShortName>${esc(title)}</ShortName>
  <Description>Search ${esc(title)} documents by title, identifier, or keyword</Description>
  <InputEncoding>UTF-8</InputEncoding>
  <OutputEncoding>UTF-8</OutputEncoding>
  <Url type="text/html" method="get" template="${site!.origin}${withBase("/")}?q={searchTerms}"/>
</OpenSearchDescription>
`;
  return new Response(xml, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
};
