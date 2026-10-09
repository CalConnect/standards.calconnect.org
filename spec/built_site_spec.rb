require "json"
require "rexml/document"

# Verifies the BUILT site against the contract (endpoints, routes,
# search decoupling). Runs only when dist has been built, so `rake
# spec` alone stays fast; CI runs it after `rake build`.
RSpec.describe "Built site" do
  let(:site_dir) { File.expand_path("../dist", __dir__) }

  let(:catalog) do
    skip("dist not built — run `rake build`") unless File.exist?(File.join(site_dir, "catalog.json"))
    JSON.parse(File.read(File.join(site_dir, "catalog.json")))
  end

  def site_path(rel)
    File.join(site_dir, rel.delete_prefix("/"))
  end

  it "serves the catalog and search index at the site root" do
    expect(File.file?(site_path("/catalog.json"))).to be(true)
    expect(File.file?(site_path("/search-index.json"))).to be(true)
  end

  it "no longer embeds the catalog in the homepage" do
    homepage = File.read(site_path("/index.html"))
    expect(homepage).not_to include('id="doc-index"')
    expect(homepage.bytesize).to be < 150_000
  end

  it "serves a valid Atom feed derived from the catalog" do
    feed = File.read(site_path("/feed.xml"))
    doc = REXML::Document.new(feed)
    ns = { "a" => "http://www.w3.org/2005/Atom" }
    entries = REXML::XPath.match(doc, "/a:feed/a:entry", ns)
    expect(entries.length).to eq(50)
    catalog_urls = catalog["items"].map { |i| i["url"] }
    entries.each do |entry|
      id = REXML::XPath.first(entry, "a:id/text()", ns).value
      expect(catalog_urls).to include(id.sub(%r{\Ahttps?://[^/]+}, ""))
    end
  end

  it "serves an OpenSearch description with a search template" do
    doc = REXML::Document.new(File.read(site_path("/opensearch.xml")))
    ns = { "os" => "http://a9.com/-/spec/opensearch/1.1/" }
    template = REXML::XPath.first(doc, "/os:OpenSearchDescription/os:Url/@template", ns)&.value
    expect(template).to include("{searchTerms}")
  end

  describe "SOTA surfaces" do
    let(:ns) { { "s" => "http://www.sitemaps.org/schemas/sitemap/0.9" } }

    it "serves a sitemap covering the canonical routes" do
      root = REXML::Document.new(File.read(site_path("/sitemap.xml")))
      urls = REXML::XPath.match(root, "/s:urlset/s:url/s:loc/text()", ns).map(&:value)
      expect(urls.length).to be >= catalog["items"].length
      expect(urls).to include(match(%r{/search/$}))
      catalog["items"].first(5).each do |item|
        expect(urls).to include(match(%r{#{Regexp.escape(item['url'])}$}))
      end
    end

    it "publishes a checksum sidecar matching the served catalog" do
      require "digest"
      sidecar = File.read(site_path("/catalog.json.sha256")).split.first
      expect(sidecar).to eq(Digest::SHA256.file(site_path("/catalog.json")).hexdigest)
    end

    it "emits citation exports and Scholar meta for every document" do
      item = catalog["items"].find { |i| i["files"].any? { |f| f["format"] == "pdf" } }
      expect(File.read(site_path("/docs/#{item['slug']}.iso690.txt"))).to include(item["id"])
      bib = File.read(site_path("/docs/#{item['slug']}.bib"))
      expect(bib).to start_with("@")

      csl = JSON.parse(File.read(site_path("/docs/#{item['slug']}.csl.json")))
      expect(csl).to be_an(Array)
      expect(csl.first).to include("id" => item["id"])
      expect(File.read(site_path("/docs/#{item['slug']}.ris"))).to match(/^TY  - /)

      landing = File.read(site_path("#{item['url']}index.html"))
      expect(landing).to include('name="citation_title"')
      expect(landing).to include("citation_pdf_url")
      expect(landing).to include("ISO 690 reference")
    end

    it "ships the full-text search index and page" do
      expect(File.file?(site_path("/search/index.html"))).to be(true)
      expect(File.directory?(site_path("/pagefind"))).to be(true)
    end

    it "surfaces bibliographic relations with cross-links" do
      item = catalog["items"].find { |i| i["relations"] && i["relations"].any? }
      skip("no relations in catalog yet") if item.nil?

      landing = File.read(site_path("#{item['url']}index.html"))
      expect(landing).to include("Related documents")
      item["relations"].each { |rel| expect(landing).to include(rel["type"]) }
    end
  end

  describe "routes" do
    it "generates a landing page with JSON-LD per item" do
      item = catalog["items"].first
      page = File.read(site_path("#{item['url']}index.html"))
      expect(page).to include(item["id"])
      jsonld = page[%r{\<script type="application/ld\+json"\>(.*?)\</script\>}m, 1]
      expect(JSON.parse(jsonld)).to include("@type" => "TechArticle")
    end

    it "generates latest aliases that redirect to the current edition" do
      catalog["items"].group_by { |i| i["document_id"] }.each_value do |group|
        current = group.find { |i| i["editions"].any? { |e| e["current"] && e["url"] == i["url"] } }
        alias_page = File.read(site_path("#{current['latest_url']}index.html"))
        expect(alias_page).to include("url=#{current['url']}")
        expect(alias_page).to include(%(rel="canonical" href="#{current['url']}"))
      end
    end

    it "generates legacy redirects for the configured prefixes" do
      item = catalog["items"].find { |i| i["files"].any? { |f| f["format"] == "html" } }
      file = item["files"].find { |f| f["format"] == "html" }
      legacy = File.join(site_dir, "cc", File.basename(file["url"]))
      expect(File.file?(legacy)).to be(true)
      expect(File.read(legacy)).to include("url=#{file['url']}")
    end
  end
end
