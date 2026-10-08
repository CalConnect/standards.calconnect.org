require "json"

RSpec.describe "Template data references" do
  let(:layouts_dir) { File.expand_path("../_layouts", __dir__) }
  let(:pages_dir) { File.expand_path("../_pages", __dir__) }
  let(:includes_dir) { File.expand_path("../_includes", __dir__) }

  it "no template references the archived layouts" do
    %w[toc.html toc-type.html].each do |layout|
      Dir.glob("#{layouts_dir}/*.html").each do |f|
        content = File.read(f)
        expect(content).not_to include("layout: #{File.basename(layout, '.html')}"),
          "#{File.basename(f)} references archived layout '#{layout}'"
      end
      Dir.glob("#{pages_dir}/*.html").each do |f|
        content = File.read(f)
        expect(content).not_to include("layout: #{File.basename(layout, '.html')}"),
          "#{File.basename(f)} references archived layout '#{layout}'"
      end
    end
  end

  it "no template references archived includes" do
    archived = %w[toc-entry.html toc-sidebar.html toc-mainPage-placeholder.html
                  disqus_comments.html feedback.html script.html find-doc.html]
    (Dir.glob("#{layouts_dir}/*.html") + Dir.glob("#{includes_dir}/*.html")).each do |f|
      content = File.read(f)
      archived.each do |inc|
        expect(content).not_to include("{% include #{inc}"),
          "#{File.basename(f)} references archived include '#{inc}'"
      end
    end
  end

  it "navigation data is referenced from header and footer" do
    header = File.read("#{includes_dir}/header.html")
    footer = File.read("#{includes_dir}/footer.html")

    expect(header).to include("site.data.navigation.categories")
    expect(footer).to include("site.data.navigation.categories")
  end

  it "doc-type layout (gem renderer) supports stage_filter_name" do
    layout = File.join(Gem.loaded_specs["standards-registry"].full_gem_path,
                       "lib", "standards-registry", "layouts", "doc-type.html")
    content = File.read(layout)
    expect(content).to include("stage_filter_name")
    expect(content).to include("site.data.navigation[page.stage_filter_name]")
  end
end
