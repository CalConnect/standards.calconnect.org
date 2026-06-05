require "yaml"

RSpec.describe "Site configuration" do
  let(:config) { YAML.load_file(File.expand_path("../_config.yml", __dir__)) }
  let(:navigation) { YAML.load_file(File.expand_path("../_data/navigation.yml", __dir__)) }

  describe "_config.yml" do
    it "has required site metadata" do
      expect(config["title"]).to eq("CalConnect Document Registry")
      expect(config["theme"]).to eq("jekyll-calconnect-theme")
    end

    it "keeps cc and relaton directories across builds" do
      expect(config["keep_files"]).to include("cc", "relaton")
    end

    it "excludes build-only directories from Jekyll processing" do
      expect(config["exclude"]).to include("src-documents/", "_archive/", "spec/")
    end
  end

  describe "_data/navigation.yml" do
    it "has categories array" do
      expect(navigation["categories"]).to be_an(Array)
      expect(navigation["categories"].length).to be >= 4
    end

    it "each category has required fields" do
      navigation["categories"].each do |cat|
        expect(cat).to have_key("title")
        expect(cat).to have_key("slug")
        expect(cat).to have_key("description")
        expect(cat).to have_key("display_category_slug")
        expect(cat).to have_key("card_color")
      end
    end

    it "category slugs are unique" do
      slugs = navigation["categories"].map { |c| c["slug"] }
      expect(slugs.uniq.length).to eq(slugs.length)
    end

    it "has draft_stages array" do
      expect(navigation["draft_stages"]).to be_an(Array)
      expect(navigation["draft_stages"]).to include("working-draft", "committee-draft")
    end
  end
end
