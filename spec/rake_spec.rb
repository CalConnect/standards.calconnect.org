RSpec.describe "Rake tasks" do
  let(:rakefile) { File.read(File.expand_path("../Rakefile", __dir__)) }

  it "defines :fetch task" do
    expect(rakefile).to include('task :fetch')
  end

  it "defines :build task (depends on :fetch)" do
    expect(rakefile).to include('task build: :fetch')
  end

  it "defines :jekyll task" do
    expect(rakefile).to include('task :jekyll')
  end

  it "defines :serve task" do
    expect(rakefile).to include('task :serve')
  end

  it "defines :clean task" do
    expect(rakefile).to include('task :clean')
  end

  it "defines :validate_schema task" do
    expect(rakefile).to include('task :validate_schema')
  end

  it "defines :spec task" do
    expect(rakefile).to include('RSpec::Core::RakeTask.new(:spec)')
  end
end
