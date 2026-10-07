# frozen_string_literal: true

require "fileutils"
require "rspec/core/rake_task"
require "yaml"

# metanorma-release's aggregate option carries a Thor default
# ("_site/cc"), which shadows metanorma.aggregate.yml's output_dir —
# pass it explicitly so the instance config controls the layout.
# (Recorded under TODO.improvements/upstream/.)
AGGREGATE_OUTPUT_DIR =
  YAML.safe_load_file("metanorma.aggregate.yml")["output_dir"] || "_site/docs"

desc "Aggregate releases and build document index"
task :fetch do
  invalidate_stale_delta_state
  sh "bundle exec metanorma-release aggregate --output-dir #{AGGREGATE_OUTPUT_DIR}"
end

# The gem skips repos whose release etags are unchanged, assuming their
# extracted files still exist under output_dir. When that directory is
# missing (fresh CI runner, wiped _site) the cache must be reset so files
# are re-extracted; downloads/ is preserved to keep re-fetch cheap.
def invalidate_stale_delta_state
  delta = File.join(".cache", "aggregate", "delta_state")
  return unless File.exist?(delta)
  return if Dir.exist?(AGGREGATE_OUTPUT_DIR) && !Dir.empty?(AGGREGATE_OUTPUT_DIR)

  FileUtils.rm_f(delta)
end

desc "Build entire site (fetch + enrich + Jekyll)"
task build: %i[fetch enrich] do
  sh "npm run build"
  sh "bundle exec jekyll build"
end

desc "Build Jekyll site (assumes fetch already done)"
task :jekyll do
  sh "npm run build"
  sh "bundle exec jekyll build"
end

desc "Serve the built site locally"
task :serve do
  sh "bundle exec jekyll serve"
end

desc "Remove all build artifacts"
task :clean do
  FileUtils.rm_rf("_site")
  FileUtils.rm_rf("registry")
end

desc "Enrich aggregated producer outputs into the registry catalog (no network)"
task :enrich do
  cfg = registry_config
  result = Registry::Enricher.new(config: cfg).run
  puts "OK: #{result.catalog.items.length} documents in #{cfg.catalog_path}"
  puts "OK: backfill report at #{cfg.backfill_path} (#{result.backfill.empty? ? 'no gaps' : 'gaps recorded'})"
end

desc "Validate registry catalog against the published schema"
task :validate_schema do
  cfg = registry_config
  require "json"
  require "json_schemer"

  schema_path = "_data/schemas/documents.schema.json"
  data_path = cfg.catalog_path

  unless File.exist?(data_path)
    abort "SKIP: #{data_path} not found — run `rake enrich` first"
  end

  schema = JSON.parse(File.read(schema_path))
  data = JSON.parse(File.read(data_path))
  schemer = JSONSchemer.schema(schema)

  errors = []
  schemer.validate(data).each do |error|
    errors << "#{error['data_pointer']}: #{error['error']}"
  end

  if errors.empty?
    puts "OK: #{data['items'].length} documents pass schema validation (#{schema['$id']})"
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

desc "Run the conformance suite: build the reference renderer against golden fixtures and check the output"
task :conformance do
  cfg = registry_config
  workspace = File.join(".tmp", "conformance")

  fixture_config = Registry::Config.new(
    aggregate_config_path: "fixtures/seed/aggregate.yml",
    registry_dir: File.join(workspace, "registry"),
    generator_label: "fixture-producer v1"
  )
  FileUtils.rm_rf(workspace)
  result = Registry::Enricher.new(config: fixture_config).run
  puts "OK: fixture catalog #{result.catalog.items.length} items"

  # The fixture producer's aggregation step: place artifacts where the
  # renderer expects them (metanorma-release does this for the instance).
  docs_dest = File.join(workspace, "_site", "docs")
  FileUtils.mkdir_p(docs_dest)
  FileUtils.cp(Dir.glob("fixtures/seed/producer/*.html") + Dir.glob("fixtures/seed/producer/*.pdf") +
               Dir.glob("fixtures/seed/producer/*.xml") + Dir.glob("fixtures/seed/producer/*.rxl") +
               Dir.glob("fixtures/seed/producer/*.doc"), docs_dest)
  FileUtils.cp_r(File.join("fixtures", "seed", "producer", "relaton"), docs_dest)

  sh "bundle exec jekyll build --config _config.yml,fixtures/seed/jekyll.yml --destination #{File.join(workspace, '_site')} > /dev/null"

  report = Registry::Conformance.check(
    File.join(workspace, "_site"),
    expect: fixture_config.catalog_path,
    schema_path: cfg.schema_path
  )
  report.failures.each { |failure| puts "  FAIL: #{failure}" }
  abort "FAIL: conformance suite (#{report.failures.length} failures)" unless report.passed

  puts "OK: conformance suite passed (#{report.checks} checks) — reference renderer certified against fixtures"
end

# SDO-agnostic registry engine configuration; instance values live in
# _config.yml (registry:) and metanorma.aggregate.yml.
def registry_config
  @registry_config ||= begin
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "registry"

    gem_version = Gem.loaded_specs["metanorma-release"]&.version.to_s
    label = "metanorma-release#{gem_version.empty? ? '' : " v#{gem_version}"} + registry-enrich v1"
    Registry::Config.new(generator_label: label).freeze
  end
end

RSpec::Core::RakeTask.new(:spec)
