# frozen_string_literal: true

require "fileutils"
require "rspec/core/rake_task"

desc "Aggregate releases and build document index"
task :fetch do
  invalidate_stale_delta_state
  sh "bundle exec metanorma-release aggregate"
end

# The gem skips repos whose release etags are unchanged, assuming their
# extracted files still exist under output_dir. When that directory is
# missing (fresh CI runner, wiped _site) the cache must be reset so files
# are re-extracted; downloads/ is preserved to keep re-fetch cheap.
def invalidate_stale_delta_state
  delta = File.join(".cache", "aggregate", "delta_state")
  return unless File.exist?(delta)
  return if Dir.exist?("_site/docs") && !Dir.empty?("_site/docs")

  FileUtils.rm_f(delta)
end

desc "Build entire site (fetch + Jekyll)"
task build: :fetch do
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
end

desc "Validate aggregated document index against schema"
task :validate_schema do
  require "json"
  require "json_schemer"

  schema_path = "_data/schemas/documents.schema.json"
  data_path = "_data/documents.json"

  unless File.exist?(data_path)
    abort "SKIP: #{data_path} not found — run `rake fetch` first"
  end

  schema = JSON.parse(File.read(schema_path))
  data = JSON.parse(File.read(data_path))
  schemer = JsonSchemer.schema(schema)

  errors = []
  data["items"].each_with_index do |doc, i|
    unless schemer.valid?(doc)
      schemer.validate(doc).each do |error|
        errors << "Document ##{i} (#{doc['id'] || 'unknown'}): #{error['error']}"
      end
    end
  end

  if errors.empty?
    puts "OK: #{data['items'].length} documents pass schema validation"
  else
    errors.first(20).each { |e| puts "  #{e}" }
    abort "FAIL: #{errors.length} schema violations found"
  end
end

RSpec::Core::RakeTask.new(:spec)
