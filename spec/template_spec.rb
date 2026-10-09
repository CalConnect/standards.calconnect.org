require "json"

RSpec.describe "Template data references" do
  let(:base_layout) { File.expand_path("../src/layouts/Base.astro", __dir__) }

  it "navigation data is referenced from the header and footer" do
    content = File.read(base_layout)
    expect(content.scan("categories.map").length).to be >= 2,
      "navigation categories must appear in both header and footer"
  end

  it "doc-type layout (gem renderer) supports stage_filter_name" do
    layout = File.join(Gem.loaded_specs["standards-registry"].full_gem_path,
                       "lib", "standards-registry", "layouts", "doc-type.html")
    content = File.read(layout)
    expect(content).to include("stage_filter_name")
    expect(content).to include("site.data.navigation[page.stage_filter_name]")
  end
end
