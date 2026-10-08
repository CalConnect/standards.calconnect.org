require "standards-registry"
require "json"
require "json_schemer"
require "tmpdir"

# Contract tests for generator independence (TODO.improvements/09): the
# hand-written fixture producer — not the metanorma-release gem — must
# produce a catalog that validates against the same published schema.
RSpec.describe "Fixture producer contract" do
  let(:schema) do
    JSON.parse(File.read(File.join(Gem.loaded_specs["standards-registry"].full_gem_path,
                                   "schema", "documents-index.schema.json")))
  end

  let(:result) do
    Dir.mktmpdir("registry-fixture") do |tmp|
      config = Registry::Config.new(
        site_config_path: File.join(Gem.loaded_specs["standards-registry"].full_gem_path, "fixtures", "seed", "instance.yml"),
        aggregate_config_path: File.join(Gem.loaded_specs["standards-registry"].full_gem_path, "fixtures", "seed", "aggregate.yml"),
        registry_dir: tmp,
        generator_label: "fixture-producer v1"
      )
      Registry::Enricher.new(config: config).build
    end
  end

  it "produces a schema-valid catalog without the gem" do
    errors = JSONSchemer.schema(schema).validate(result.catalog.to_h).map { |e| e["error"] }
    expect(errors).to be_empty, -> { errors.first(5).join("; ") }
  end

  it "computes integrity metadata from the fixture artifacts" do
    item = result.catalog.items.find { |i| i["slug"] == "fx-1001-2024" }
    expect(item["files"].map { |f| f["format"] }).to eq(%w[html pdf xml rxl])
    expect(item["files"].first).to include("media_type" => "text/html", "bytes" => kind_of(Integer),
                                           "sha256" => /^[a-f0-9]{64}$/, "url" => "/docs/fx-1001-2024.html")
  end

  it "builds the editions model across the multi-edition document" do
    latest = result.catalog.items.find { |i| i["slug"] == "fx-1001-2024" }
    older = result.catalog.items.find { |i| i["slug"] == "fx-1001-2022" }
    expect(latest["editions"].length).to eq(2)
    expect(latest["editions"].select { |e| e["current"] }.length).to eq(1)
    expect(latest["latest_url"]).to eq("/docs/fx-1001/")
    expect(older["url"]).to eq("/docs/fx-1001/2022/")
    expect(latest["url"]).to eq("/docs/fx-1001/2024/")
  end

  it "mints urns from the instance namespace" do
    item = result.catalog.items.first
    expect(item["urn"]).to start_with("urn:fixture:")
  end

  it "keeps unprovided fields honestly null and tracked" do
    report = result.catalog.items
    unlicensed = report.reject { |i| i["license"] }
    expect(unlicensed.length).to eq(3)
    expect(result.backfill.empty?).to be(false)
  end

  it "derives the search index as a subset view" do
    documents = result.search_index.to_h["documents"]
    expect(documents.length).to eq(3)
    expect(documents.first.keys).to eq(%w[slug document_id id title abstract doctype stage date url])
    expect(documents.map { |d| d["url"] }).to all(start_with("/docs/"))
  end
end
