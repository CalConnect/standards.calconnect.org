# frozen_string_literal: true

require "fileutils"
require "json"
require "rspec/core/rake_task"
require "yaml"

# Run a block with selected environment variables set (bundler-safe).
def with_env(vars)
  saved = vars.keys.to_h { |k| [k, ENV[k]] }
  vars.each { |k, v| ENV[k] = v }
  yield
ensure
  saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
end

# metanorma-release's aggregate option carries a Thor default
# ("_site/cc"), which shadows metanorma.aggregate.yml's output_dir —
# pass it explicitly so the instance config controls the layout.
# (Recorded under TODO.improvements/upstream/.)
AGGREGATE_OUTPUT_DIR =
  YAML.safe_load_file("metanorma.aggregate.yml")["output_dir"] || "_site/docs"

SITE_DIR = "dist"

def invalidate_stale_delta_state
  delta = File.join(".cache", "aggregate", "delta_state")
  return unless File.exist?(delta)
  return if Dir.exist?(AGGREGATE_OUTPUT_DIR) && !Dir.empty?(AGGREGATE_OUTPUT_DIR)

  FileUtils.rm_f(delta)
end

# SDO-agnostic registry engine configuration; instance values live in
# _config.yml (registry:) and metanorma.aggregate.yml.
def registry_config
  @registry_config ||= begin
    require "standards-registry"

    gem_version = Gem.loaded_specs["metanorma-release"]&.version.to_s
    label = "metanorma-release#{gem_version.empty? ? '' : " v#{gem_version}"} + registry-enrich v1"
    Registry::Config.new(generator_label: label).freeze
  end
end

desc "Aggregate releases and build document index"
task :fetch do
  invalidate_stale_delta_state
  sh "bundle exec metanorma-release aggregate --output-dir #{AGGREGATE_OUTPUT_DIR}"
end

desc "Enrich aggregated producer outputs into the registry catalog (no network)"
task :enrich do
  cfg = registry_config
  result = Registry::Enricher.new(config: cfg).run
  puts "OK: #{result.catalog.items.length} documents in #{cfg.catalog_path}"
  puts "OK: backfill report at #{cfg.backfill_path} (#{result.backfill.empty? ? 'no gaps' : 'gaps recorded'})"
end

desc "Generate per-document citation exports via relaton-ts (ISO 690, BibTeX, RIS, CSL)"
task :citations do
  sh "node scripts/generate-citations.mjs"
end

desc "Assemble the built site: artifacts, citations, legacy redirects, full-text index"
task :finalize do
  docs_dest = File.join(SITE_DIR, "docs")
  FileUtils.mkdir_p(docs_dest)
  # Artifacts extracted by the aggregator serve at /docs/
  if Dir.exist?(AGGREGATE_OUTPUT_DIR)
    files = Dir.glob(File.join(AGGREGATE_OUTPUT_DIR, "**", "*")).select { |f| File.file?(f) }
    files.each do |f|
      rel = f.delete_prefix(AGGREGATE_OUTPUT_DIR + "/")
      dest = File.join(docs_dest, rel)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(f, dest)
    end
    puts "OK: #{files.length} artifacts finalized into /docs/"
  end
  # Citation exports serve at /docs/{slug}.{ext}
  if Dir.exist?("registry/citations")
    cited = Dir.glob("registry/citations/*")
    cited.each { |f| FileUtils.cp(f, File.join(docs_dest, File.basename(f))) }
    puts "OK: #{cited.length} citation files finalized into /docs/"
  end
  # Legacy /cc/ HTML redirects (meta refresh to the artifact)
  catalog = JSON.parse(File.read(registry_config.catalog_path))
  stub = lambda do |url|
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head><meta charset="utf-8"><title>#{url}</title>
      <link rel="canonical" href="#{url}">
      <meta http-equiv="refresh" content="0; url=#{url}"></head>
      <body><p>This document has moved to <a href="#{url}">#{url}</a>.</p></body>
      </html>
    HTML
  end
  legacy = 0
  legacy_prefixes = YAML.safe_load_file("_config.yml").dig("registry", "legacy_prefixes") || []
  legacy_prefixes.each do |prefix|
    catalog["items"].each do |item|
      item["files"].each do |file|
        next unless file["format"] == "html"

        dest = File.join(SITE_DIR, prefix, File.basename(file["url"]))
        next if File.exist?(dest)

        FileUtils.mkdir_p(File.dirname(dest))
        File.write(dest, stub.call(file["url"]))
        legacy += 1
      end
    end
  end
  puts "OK: #{legacy} legacy redirect stubs"
  sh "npx pagefind --site #{SITE_DIR} --root-selector main"
end

# Build guard: an aggregation that yields zero documents must fail, and a
# sudden large shrinkage (e.g. a rate-limited run silently skipping
# repos) must not silently ship a gutted registry. The previous good
# count persists in .cache/registry-count.
def guard_nonempty_catalog
  count = JSON.parse(File.read(registry_config.catalog_path))["items"].length
  abort "FAIL: build produced 0 documents — refusing to ship an empty registry" if count.zero?

  marker = File.join(".cache", "registry-count")
  previous = File.exist?(marker) ? File.read(marker).to_i : nil
  if previous && count < previous * 0.9
    abort "FAIL: catalog shrank #{previous} -> #{count} (>10% drop) — refusing to ship; " \
          "likely transient aggregation failures (rate limits). Re-run before accepting."
  end
  File.write(marker, count.to_s) if count.positive?

  puts "OK: #{count} documents in the published catalog#{previous ? " (was #{previous})" : ''}"
rescue Errno::ENOENT
  abort "FAIL: registry/catalog.json missing after build"
end

desc "Build entire site (fetch + enrich + citations + Astro + finalize)"
task build: %i[fetch enrich citations] do
  sh "npm run build"
  Rake::Task["finalize"].invoke
  guard_nonempty_catalog
end

desc "Build the Astro site (assumes enrich already done)"
task site: %i[citations] do
  sh "npm run build"
  Rake::Task["finalize"].invoke
end

desc "Serve the built site locally"
task :serve do
  sh "npx astro preview"
end

desc "Remove all build artifacts"
task :clean do
  FileUtils.rm_rf(%w[dist registry .artifacts])
end

desc "Validate catalog and search index against the published schemas"
task :validate_schema do
  cfg = registry_config
  require "json"
  require "json_schemer"

  unless File.exist?(cfg.catalog_path)
    abort "SKIP: #{cfg.catalog_path} not found — run `rake enrich` first"
  end

  errors = []
  schema_dir = File.dirname(cfg.schema_path)
  [[File.join(schema_dir, "documents-index.schema.json"), cfg.catalog_path],
   [File.join(schema_dir, "search-index.schema.json"), cfg.search_index_path]].each do |schema_path, data_path|
    next unless File.exist?(data_path)

    schema = JSON.parse(File.read(schema_path))
    data = JSON.parse(File.read(data_path))
    JSONSchemer.schema(schema).validate(data).each do |error|
      errors << "#{File.basename(data_path)}#{error['data_pointer']}: #{error['error']}"
    end
  end

  if errors.empty?
    puts "OK: catalog and search index pass schema validation"
  else
    errors.first(20).each { |e| puts "  #{e}" }
    abort "FAIL: #{errors.length} schema violations found"
  end
end

desc "Recompute Relaton projections and verify catalog integrity"
task :validate_consistency do
  cfg = registry_config
  result = Registry::Consistency.new(cfg).run
  if result.ok?
    puts "OK: catalog consistent — projections, files, URLs, editions verified"
  else
    result.problems.first(20).each { |p| puts "  #{p}" }
    abort "FAIL: #{result.problems.length} consistency violations found"
  end
end

desc "Verify every internal link in the built site resolves"
task :verify_links do
  abort "SKIP: #{SITE_DIR} not found — run `rake build` first" unless File.directory?(SITE_DIR)

  html_files = Dir.glob(File.join(SITE_DIR, "**", "*.html"))
  broken = []
  checked = 0
  html_files.each do |file|
    content = File.read(file).gsub(/<script\b.*?<\/script>/m, "")
    refs = content.scan(%r{(?:href|src)="([^"]+)"}).flatten
    refs.each do |ref|
      next if ref.start_with?("http", "//", "ftp:", "mailto:", "tel:", "data:", "#")
      next if ref.empty?

      target = ref.split("#").first.split("?").first
      next if target.empty?

      resolved = File.join(SITE_DIR, target)
      resolved = File.join(resolved, "index.html") if File.directory?(resolved)
      checked += 1
      unless File.file?(resolved)
        broken << "#{file.sub(SITE_DIR + '/', '')} -> #{ref}"
      end
    end
  end

  if broken.empty?
    puts "OK: #{checked} internal links across #{html_files.length} pages all resolve"
  else
    broken.first(25).each { |b| puts "  BROKEN: #{b}" }
    abort "FAIL: #{broken.length} broken internal links"
  end
end

desc "Report catalog changes against a deployed registry"
task :report_changes, [:base_url] do |_t, args|
  require "net/http"
  require "uri"

  base = args[:base_url] || "https://standards.calconnect.org"
  uri = URI.join(base, "/catalog.json")
  response = Net::HTTP.get_response(uri)
  unless response.is_a?(Net::HTTPSuccess)
    puts "NOTE: #{uri} unreachable (#{response.code}) — skipping change report"
    next
  end

  remote = JSON.parse(response.body)
  local = JSON.parse(File.read(registry_config.catalog_path))
  remote_items = remote["items"].to_h { |i| [i["slug"], i] }
  local_items = local["items"].to_h { |i| [i["slug"], i] }

  added = local_items.keys - remote_items.keys
  removed = remote_items.keys - local_items.keys
  changed = (local_items.keys & remote_items.keys).select do |slug|
    %w[title date stage edition].any? { |f| local_items[slug][f] != remote_items[slug][f] }
  end

  puts "Catalog changes vs #{base}:"
  puts "  + #{added.length} new: #{added.sort.first(10).join(', ')}#{' …' if added.length > 10}"
  puts "  - #{removed.length} removed: #{removed.sort.first(10).join(', ')}#{' …' if removed.length > 10}"
  puts "  ~ #{changed.length} changed: #{changed.sort.first(10).join(', ')}#{' …' if changed.length > 10}"
  puts "  = #{local_items.length} documents total (was #{remote_items.length})"

  summary = ENV["GITHUB_STEP_SUMMARY"]
  if summary
    File.open(summary, "a") do |f|
      f.puts "## Catalog changes vs #{base}\n"
      f.puts "+ **#{added.length} new**, ~ **#{changed.length} changed**, - **#{removed.length} removed** — #{local_items.length} total (was #{remote_items.length})\n"
      f.puts "New: #{added.sort.map { |s| local_items[s]['id'] }.join(', ')}\n\n" unless added.empty?
      f.puts "Removed: #{removed.sort.map { |s| remote_items[s]['id'] }.join(', ')}\n\n" unless removed.empty?
    end
  end
end

desc "Validate any catalog file against the registry schema (09)"
task :validate_index, [:path] do |_t, args|
  cfg = registry_config
  require "json"
  require "json_schemer"

  path = args[:path]
  abort "usage: rake validate_index[path/to/catalog.json]" unless path
  abort "not found: #{path}" unless File.exist?(path)

  schema = JSON.parse(File.read(cfg.schema_path))
  data = JSON.parse(File.read(path))
  schemer = JSONSchemer.schema(schema)

  errors = []
  schemer.validate(data).each { |error| errors << error["error"] }
  if errors.empty?
    puts "OK: #{path} conforms to #{schema['$id']}"
  else
    errors.first(20).each { |e| puts "  #{e}" }
    abort "FAIL: #{path}: #{errors.length} schema violations"
  end
end

desc "Certify the built site and a fixture build with registry-conformance"
task conformance: %i[build] do
  cfg = registry_config
  engine = File.expand_path(Gem.loaded_specs["standards-registry"].full_gem_path)

  # 1. The instance's own built site, against its own contract.
  sh "#{File.join(engine, 'bin', 'registry-conformance')} check #{SITE_DIR} " \
     "--expect #{cfg.catalog_path} --schema #{cfg.schema_path}"

  # 2. A fixture build: the golden catalog through the same Astro pipeline.
  fixtures = File.join(engine, "fixtures", "seed")
  workspace = File.join(".tmp", "conformance")
  fixture_config = Registry::Config.new(
    site_config_path: File.join(fixtures, "instance.yml"),
    aggregate_config_path: File.join(fixtures, "aggregate.yml"),
    registry_dir: File.join(workspace, "registry"),
    generator_label: "fixture-producer v1"
  )
  FileUtils.rm_rf(workspace)
  result = Registry::Enricher.new(config: fixture_config).run
  puts "OK: fixture catalog #{result.catalog.items.length} items"

  with_env({ "REGISTRY_DIR" => File.join(workspace, "registry") }) do
    sh "npm run build > /dev/null"
  end
  # fixture artifacts serve at /docs/
  FileUtils.cp(Dir.glob(File.join(fixtures, "producer", "*")).select { |f| File.file?(f) },
               File.join(SITE_DIR, "docs"))

  sh "#{File.join(engine, 'bin', 'registry-conformance')} check #{SITE_DIR} " \
     "--expect #{fixture_config.catalog_path} --schema #{cfg.schema_path}"
  puts "OK: conformance suite passed — instance site and fixture build certified"
end

RSpec::Core::RakeTask.new(:spec)
