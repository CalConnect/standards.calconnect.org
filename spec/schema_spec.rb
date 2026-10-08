require "json"
require "json_schemer"
require "standards-registry"

RSpec.describe "Registry catalog schema" do
  let(:schema_path) { File.join(Gem.loaded_specs["standards-registry"].full_gem_path, "schema", "documents-index.schema.json") }
  let(:schema) { JSON.parse(File.read(schema_path)) }

  let(:data_path) { File.expand_path("../registry/catalog.json", __dir__) }
  let(:catalog) do
    skip("registry/catalog.json not found — run `rake enrich`") unless File.exist?(data_path)
    JSON.parse(File.read(data_path))
  end

  it "has contract identity" do
    expect(schema["$id"]).to eq("https://schemas.metanorma.org/registry/documents-index/v1.json")
    expect(schema.dig("properties", "version", "const")).to eq(1)
  end

  it "requires integrity fields on every artifact locator" do
    file_props = schema.dig("$defs", "file", "properties")
    expect(file_props.keys).to include("format", "media_type", "bytes", "sha256", "url")
    expect(schema.dig("$defs", "document", "properties")).not_to have_key("formats")
  end

  it "the catalog validates against the published schema" do
    errors = JSONSchemer.schema(schema).validate(catalog).map { |e| e["error"] }
    expect(errors).to be_empty, -> { "Schema violations:\n  #{errors.first(10).join("\n  ")}" }
  end

  it "the search index validates against its derived-view schema" do
    search_path = File.expand_path("../registry/search-index.json", __dir__)
    skip("registry/search-index.json not found") unless File.exist?(search_path)
    search_schema_path = File.join(Gem.loaded_specs["standards-registry"].full_gem_path, "schema", "search-index.schema.json")
    search_schema = JSON.parse(File.read(search_schema_path))
    search = JSON.parse(File.read(search_path))
    expect(search_schema["$id"]).to eq("https://schemas.metanorma.org/registry/search-index/v1.json")
    errors = JSONSchemer.schema(search_schema).validate(search).map { |e| e["error"] }
    expect(errors).to be_empty, -> { errors.first(5).join("; ") }
    expect(search["documents"].length).to eq(catalog["items"].length)
  end

  it "carries the schema reference and version in the payload" do
    expect(catalog["$schema"]).to eq(schema["$id"])
    expect(catalog["version"]).to eq(1)
    expect(catalog["generated_at"]).to be_a(String)
    expect(catalog["items"]).to be_an(Array)
    expect(catalog["items"].length).to be > 100
  end
end
