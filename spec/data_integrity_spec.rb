require "json"
require "set"

RSpec.describe "Data integrity" do
  let(:nav_path) { File.expand_path("../_data/navigation.yml", __dir__) }
  let(:nav) { YAML.load_file(nav_path) }
  let(:data_path) { File.expand_path("../registry/catalog.json", __dir__) }

  let(:docs) do
    skip("registry/catalog.json not found — run `rake enrich`") unless File.exist?(data_path)
    JSON.parse(File.read(data_path))["items"]
  end

  describe "navigation <-> data consistency" do
    it "every display_category_slug in the catalog maps to a navigation category" do
      nav_slugs = nav["categories"].map { |c| c["display_category_slug"] }.to_set
      docs.each do |doc|
        slug = doc["display_category_slug"]
        next if slug.nil?

        expect(nav_slugs).to include(slug), -> {
          "#{doc['id']}: display_category_slug '#{slug}' not in navigation categories"
        }
      end
    end
  end

  describe "document uniqueness" do
    it "slug+edition pairs are unique (same slug may carry distinct editions)" do
      keys = docs.map { |d| [d["slug"], d["edition"]] }
      duplicates = keys.group_by(&:itself).select { |_, v| v.length > 1 }.keys
      expect(duplicates).to be_empty, -> {
        "Duplicate slug+edition documents: #{duplicates.join(', ')}"
      }
    end

    it "landing URLs are unique (superseded editions retain their own pages)" do
      urls = docs.map { |d| d["url"] }
      duplicates = urls.group_by(&:itself).select { |_, v| v.length > 1 }.keys
      expect(duplicates).to be_empty, -> { "Colliding landing URLs: #{duplicates.join(', ')}" }
    end
  end

  describe "data honesty" do
    it "sources every license from Relaton or the instance rights default — never invented" do
      config = YAML.load_file(File.expand_path("../_config.yml", __dir__))
      default = config.dig("registry", "license_default")
      docs.each do |doc|
        relaton_license = doc.dig("bibliographic", "license")&.first
        expected = relaton_license || default
        expect(doc["license"]).to eq(expected), -> {
          "#{doc['slug']}: license neither from Relaton nor the configured default"
        }
      end
    end

    it "records gaps rather than omitting them" do
      backfill_path = File.expand_path("../registry/backfill.json", __dir__)
      skip("registry/backfill.json not found") unless File.exist?(backfill_path)
      backfill = JSON.parse(File.read(backfill_path))
      docs.each do |doc|
        next unless doc["abstract"].nil?

        slugs = backfill.dig("gaps", "missing_abstract").to_a.map { |g| g["slug"] }
        expect(slugs).to include(doc["slug"]), -> {
          "#{doc['slug']}: null abstract not tracked in backfill report"
        }
      end
    end
  end
end
