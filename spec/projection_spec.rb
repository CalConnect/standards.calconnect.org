$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "registry"

RSpec.describe "Registry::Projection" do
  let(:bib) do
    {
      "title" => [{ "content" => "Explicit representation ", "type" => "main" }],
      "docidentifier" => [
        { "content" => "Other", "type" => "alt" },
        { "content" => "CC 18011:2018", "type" => "CalConnect", "primary" => true },
      ],
      "abstract" => [{ "content" => "An abstract." }],
      "ext" => { "doctype" => { "content" => "standard" } },
      "status" => { "stage" => { "content" => "Published" } },
      "date" => [{ "type" => "circulated", "at" => "2018-01-01" },
                 { "type" => "published", "at" => "2018-09-18" }],
      "language" => ["en"],
      "copyright" => [{ "from" => "2018",
                        "owner" => [{ "organization" => { "name" => [{ "content" => "CalConnect" }] } }] }],
      "contributor" => [
        { "person" => { "name" => { "given" => { "content" => "Ada" }, "surname" => "Lovelace" } },
          "role" => [{ "type" => "author" }] },
        { "organization" => { "name" => [{ "content" => "CalConnect" }],
                               "subdivision" => [{ "name" => [{ "content" => "DATETIME" }] }] } },
      ],
      "schema_version" => "v1.5.6",
    }
  end
  let(:raw) { { "id" => "cc-18011-2018", "identifier" => "fallback", "stage" => "draft" } }

  it "projects the primary docidentifier as the display id" do
    expect(Registry::Projection.identifier(bib, raw)).to eq("CC 18011:2018")
  end

  it "strips the main Relaton title" do
    expect(Registry::Projection.title(bib, raw)).to eq("Explicit representation")
  end

  it "prefers the Relaton published date" do
    expect(Registry::Projection.date(bib, raw)).to eq("2018-09-18")
  end

  it "downcases the Relaton stage over the release stage" do
    expect(Registry::Projection.stage(bib, raw)).to eq("published")
    expect(Registry::Projection.stage({}, raw)).to eq("draft")
    expect(Registry::Projection.stage({}, {})).to eq("published")
  end

  it "falls back to release doctype when Relaton is silent" do
    expect(Registry::Projection.doctype(bib, raw)).to eq("standard")
    expect(Registry::Projection.doctype({}, { "doctype" => "report" })).to eq("report")
  end

  it "maps contributors to authors and committee" do
    expect(Registry::Projection.authors(bib)).to eq([{ "name" => "Ada Lovelace", "role" => "author" }])
    expect(Registry::Projection.committee(bib)).to eq("DATETIME")
  end

  it "never invents a license" do
    expect(Registry::Projection.license(bib, nil)).to be_nil
    expect(Registry::Projection.license({}, nil)).to be_nil
    expect(Registry::Projection.license({ "license" => [{ "name" => "CC-BY-4.0",
                                                          "url" => "https://example.org/cc-by" }] }, nil))
      .to eq({ "name" => "CC-BY-4.0", "url" => "https://example.org/cc-by" })
  end
end

RSpec.describe "Registry::Urls" do
  let(:ed1) { { "slug" => "d-2010", "document_id" => "d", "edition" => "1", "date" => "2010-10-14", "year" => "2010" } }
  let(:ed11) { { "slug" => "d-2010", "document_id" => "d", "edition" => "1.1", "date" => "2010-10-14", "year" => "2010" } }
  let(:group) { [ed1, ed11] }

  it "derives the document identity from the per-version slug" do
    expect(Registry::Projection.document_id("cc-18011-2018")).to eq("cc-18011")
    expect(Registry::Projection.document_id("cc-wd-51017-2024-07-23")).to eq("cc-wd-51017-2024-07-23")
  end

  it "disambiguates same-year editions deterministically" do
    expect(Registry::Urls.version_segment(ed1, group)).to eq("2010-ed1")
    expect(Registry::Urls.version_segment(ed11, group)).to eq("2010-ed1.1")
  end

  it "uses the plain year when unique" do
    lone = [{ "slug" => "d-2018", "document_id" => "d", "edition" => "1", "year" => "2018" }]
    expect(Registry::Urls.version_segment(lone.first, lone)).to eq("2018")
  end

  it "renders the landing path from the configured scheme" do
    expect(Registry::Urls.landing_path(ed1, group, "/docs/:document_id/:year/"))
      .to eq("/docs/d/2010-ed1/")
  end
end
