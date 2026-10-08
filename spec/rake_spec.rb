RSpec.describe "Rake tasks" do
  let(:rakefile) { File.read(File.expand_path("../Rakefile", __dir__)) }

  it "defines :fetch task" do
    expect(rakefile).to include("task :fetch")
  end

  it "defines :enrich task (no network)" do
    expect(rakefile).to include("task :enrich")
  end

  it "defines :build task (fetch + enrich + citations + jekyll)" do
    expect(rakefile).to include("task build: %i[fetch enrich citations]")
  end

  it "defines :jekyll task (depends on citations)" do
    expect(rakefile).to include("task jekyll: :citations")
  end

  it "defines :serve task" do
    expect(rakefile).to include("task :serve")
  end

  it "defines :clean task (site + registry)" do
    expect(rakefile).to include("task :clean")
    expect(rakefile).to match(/FileUtils\.rm_rf\("registry"\)/)
  end

  it "defines :citations task (relaton-ts exports)" do
    expect(rakefile).to include("task :citations")
    expect(rakefile).to include("generate-citations.mjs")
  end

  it "defines validation tasks" do
    expect(rakefile).to include("task :validate_schema")
    expect(rakefile).to include("task :validate_consistency")
    expect(rakefile).to include("task :validate_index")
  end

  it "defines :conformance task" do
    expect(rakefile).to include("task :conformance")
  end

  it "defines :spec task" do
    expect(rakefile).to include("RSpec::Core::RakeTask.new(:spec)")
  end
end
