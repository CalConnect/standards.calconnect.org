RSpec.describe "Template data references" do
  let(:base_layout) { File.expand_path("../src/layouts/Base.astro", __dir__) }

  it "navigation data is referenced from the header and footer" do
    content = File.read(base_layout)
    expect(content.scan("categories.map").length).to be >= 2,
      "navigation categories must appear in both header and footer"
  end
end
