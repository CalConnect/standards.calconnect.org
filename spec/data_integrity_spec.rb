require "json"

RSpec.describe "Data integrity" do
  let(:nav_path) { File.expand_path("../_data/navigation.yml", __dir__) }
  let(:nav) { YAML.load_file(nav_path) }
  let(:data_path) { File.expand_path("../_data/documents.json", __dir__) }

  let(:docs) do
    skip("documents.json not found — run `rake fetch`") unless File.exist?(data_path)
    JSON.parse(File.read(data_path))["items"]
  end

  describe "navigation ↔ data consistency" do
    it "every display_category_slug in documents maps to a navigation category" do
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
    it "document IDs are unique (known issue: CC/R 1012:2010)" do
      ids = docs.map { |d| d["id"] }
      duplicates = ids.group_by(&:itself).select { |_, v| v.length > 1 }.keys
      expect(duplicates).to be_empty, -> {
        "Duplicate document IDs: #{duplicates.join(', ')}"
      }
    end if ENV["STRICT_IDS"]
  end
end
