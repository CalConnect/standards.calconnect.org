# metanorma-release Bugs Found During Integration

## Bug 1: CLI defaults override YAML config values

**Location:** `lib/metanorma/release/cli.rb` — `option :file_routing` default `"by-document"`

**Problem:** The Thor CLI option `--file-routing` has a hardcoded default of `"by-document"`. In `AggregateCommand.merge_config`, the merge logic uses `cli_options[:file_routing] || file_data["file_routing"]`. Since Thor always provides its default value (not `nil`), the YAML config's `file_routing` can never take effect when running through the CLI.

**Impact:** Any `file_routing` value in `metanorma.aggregate.yml` is silently ignored. Users who set `file_routing: flat` in their config will get `by-document` routing instead, causing file paths in the generated data to not match their layout templates.

**Fix:** Use `nil` as the CLI default for `file_routing` (and other options that should defer to the YAML config). Only apply the hardcoded default inside `merge_config` when both the CLI option and YAML value are absent:

```ruby
# cli.rb — remove the default from the Thor option
option :file_routing, type: :string, desc: "File routing (by-document|flat|by-format)"

# aggregate.rb — apply default in merge_config
file_routing: cli_options[:file_routing] || file_data["file_routing"] || "by-document",
```

---

## Bug 2: Channel filter uses exact match, not prefix/hierarchical matching

**Location:** `lib/metanorma/release/channel_filter.rb` — `channel_match?`

**Problem:** The `MetadataFilter` compares channels via exact string equality (`Channel#eql?` compares `@name == other.name`). A filter channel of `"public"` does not match documents with channels like `"public/standards"`, `"public/directives"`, etc.

This is surprising because the YAML config key `channels: ["public"]` reads as "accept all public channels", but the filter rejects everything — no documents have a bare `"public"` channel.

**Impact:** If a user sets `channels: ["public"]` in `metanorma.aggregate.yml`, zero documents are aggregated on a fresh build. The pipeline silently succeeds with 0 documents (no error is raised unless `min_documents` is set).

Note: the pipeline may appear to work if a cached delta state exists from a previous run that didn't have the channel filter, because the delta state bypasses the channel check for already-processed releases.

**Suggested fix:** Either document that channels must be specified exactly (e.g., `channels: ["public/standards", "public/directives", ...]`), or implement hierarchical matching where `"public"` matches any channel starting with `"public/"`.

---

## Bug 3: `flatten_for_site` omits computed properties needed by site templates

**Location:** `lib/metanorma/release/site.rb` — `flatten_for_site`

**Problem:** The `flatten_for_site` method produces a flat hash with raw fields (`slug`, `id`, `title`, `stage`, `doctype`, `formats`, `files`, etc.) but omits convenience properties that site templates typically need:

- **Format availability flags** (`has_html`, `has_pdf`, `has_xml`, `has_rxl`) — Templates need to know which formats are available to conditionally render download links.
- **Stage display info** (`stage_css`, `stage_abbr`) — The raw `stage` value is exposed directly, but templates typically need a CSS class name and a human-readable abbreviation.
- **Doctype CSS class** (`doctype_class`) — Templates need a stable CSS class derived from the doctype.

**Impact:** Every site that consumes `_data/documents.json` must re-derive these computed properties in its template layer.

**Suggested fix:** Add these convenience fields to `flatten_for_site`:

```ruby
{
  # ... existing fields ...
  "has_html" => formats.include?("html"),
  "has_pdf"  => formats.include?("pdf"),
  "has_xml"  => formats.include?("xml"),
  "has_rxl"  => formats.include?("rxl"),
  "stage_css" => stage.to_s.downcase.gsub(/\s+/, "-"),
  "stage_abbr" => abbreviate_stage(stage),
  "doctype_class" => "type-#{doctype.to_s.downcase}",
}
```

---

## Bug 4: `extract_date` ignores document revdate, uses only GitHub release date

**Location:** `lib/metanorma/release/site.rb` — `extract_date`

**Problem:** The `extract_date` method only uses `doc.dig("source", "releaseDate")` (the GitHub release published timestamp). It ignores `doc["revdate"]` which contains the actual document publication date from the release metadata.

```ruby
def extract_date(doc)
  release_date = doc.dig("source", "releaseDate")
  return nil unless release_date
  release_date.to_s.split(/[T ]/).first
end
```

**Impact:** When documents are all released on the same day (e.g., bulk publication on 2026-05-13), all documents show that same date regardless of their actual publication dates (which can be years earlier). For example, CC 18011:2018 (published 2018-09-18) would show `2026-05-13`.

Documents with `revdate: null` in their release metadata have no fallback to the actual document date.

**Fix:** Prefer `revdate` from the document metadata, fall back to release date only when revdate is absent:

```ruby
def extract_date(doc)
  revdate = doc["revdate"]
  return revdate.to_s.split(/[T ]/).first if revdate && !revdate.to_s.empty?

  release_date = doc.dig("source", "releaseDate")
  return nil unless release_date
  release_date.to_s.split(/[T ]/).first
end
```
