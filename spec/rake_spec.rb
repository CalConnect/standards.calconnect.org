RSpec.describe "Rake tasks" do
  let(:rakefile) { File.read(File.expand_path("../Rakefile", __dir__)) }

  it "defines :fetch task" do
    expect(rakefile).to include("task :fetch")
  end

  it "defines :enrich task (no network)" do
    expect(rakefile).to include("task :enrich")
  end

  it "defines :build task (fetch + enrich + jekyll)" do
    expect(rakefile).to include("task build: %i[fetch enrich]")
  end

  it "defines :jekyll task" do
    expect(rakefile).to include("task :jekyll")
  end

  it "defines :serve task" do
    expect(rakefile).to include("task :serve")
  end

  it "defines :clean task (site + registry)" do
    expect(rakefile).to include("task :clean")
    expect(rakefile).to match(/FileUtils\.rm_rf\("registry"\)/)
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
