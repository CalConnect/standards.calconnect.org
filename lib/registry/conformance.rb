# frozen_string_literal: true

require "json"
require "rexml/document"

module Registry
  # Registry Frontend Conformance Profile checker (TODO.improvements/09,
  # 12): validates a BUILT site directory against the contract it serves.
  # Stack-agnostic — the site may be produced by the reference Jekyll
  # renderer or any conforming frontend. Ground truth is the catalog
  # (served at /catalog.json, optionally cross-checked against the
  # producer's copy via expect:).
  #
  # Required when features.html is not disabled (default):
  #   - routes: versioned landing page per item, latest alias redirect
  #     per document group, every files[].url resolves to a real file
  #   - semantics: JSON-LD on landing pages
  #   - behaviors: landing pages link every files[].url
  # Always required (headless included):
  #   - /catalog.json present and schema-valid
  #   - /search-index.json present; document urls ⊆ catalog urls
  #   - /feed.xml well-formed Atom; entry ids resolve to catalog items
  #   - /opensearch.xml well-formed with a search Url template
  class Conformance
    Report = Struct.new(:passed, :failures, :checks, keyword_init: true)

    def self.check(site_dir, expect: nil, schema_path: nil, html: true)
      new(site_dir, expect: expect, schema_path: schema_path, html: html).run
    end

    def initialize(site_dir, expect:, schema_path:, html:)
      @site_dir = site_dir
      @expect = expect
      @schema_path = schema_path
      @html = html
      @failures = []
      @checks = 0
    end

    def run
      catalog = check_catalog
      check_search_index(catalog)
      check_feed(catalog)
      check_opensearch
      check_routes(catalog) if @html
      Report.new(passed: @failures.empty?, failures: @failures, checks: @checks)
    end

    private

    def read_json(rel)
      path = File.join(@site_dir, rel)
      return nil unless File.file?(path)

      JSON.parse(File.read(path))
    end

    def check_catalog
      catalog = read_json("catalog.json")
      if catalog.nil?
        fail_check("/catalog.json missing")
        return { "items" => [] }
      end

      @checks += 1
      if @schema_path && File.exist?(@schema_path)
        require "json_schemer"
        schema = JSON.parse(File.read(@schema_path))
        errors = JSONSchemer.schema(schema).validate(catalog).map { |e| e["error"] }
        fail_check("/catalog.json schema violations: #{errors.first(3).join('; ')}") unless errors.empty?
      end

      if @expect
        expected = JSON.parse(File.read(@expect))
        if expected["items"].length != catalog["items"].length ||
           (expected["items"].map { |i| i["url"] }.sort != catalog["items"].map { |i| i["url"] }.sort)
          fail_check("/catalog.json does not match the producer's catalog")
        end
      end
      catalog
    end

    def check_search_index(catalog)
      search = read_json("search-index.json")
      return fail_check("/search-index.json missing") if search.nil?

      @checks += 1
      catalog_urls = catalog["items"].map { |i| i["url"] }
      unknown = Array(search["documents"]).map { |d| d["url"] }.uniq - catalog_urls.uniq
      fail_check("/search-index.json references non-catalog urls: #{unknown.first(3).join(', ')}") unless unknown.empty?
    end

    def check_feed(catalog)
      path = File.join(@site_dir, "feed.xml")
      return fail_check("/feed.xml missing") unless File.file?(path)

      @checks += 1
      doc = REXML::Document.new(File.read(path))
      ns = { "a" => "http://www.w3.org/2005/Atom" }
      feed_id = REXML::XPath.first(doc, "/a:feed/a:id/text()", ns)&.value
      fail_check("/feed.xml missing feed id") if feed_id.nil?

      catalog_urls = catalog["items"].map { |i| i["url"] }
      entries = REXML::XPath.match(doc, "/a:feed/a:entry", ns)
      unresolved = entries.map do |entry|
        id = REXML::XPath.first(entry, "a:id/text()", ns).value
        id.sub(%r{\Ahttps?://[^/]+}, "")
      end.reject { |path_url| catalog_urls.include?(path_url) }
      fail_check("/feed.xml entries not resolving to catalog items: #{unresolved.first(3).join(', ')}") unless unresolved.empty?
    rescue REXML::ParseException => e
      fail_check("/feed.xml is not well-formed XML: #{e.message}")
    end

    def check_opensearch
      path = File.join(@site_dir, "opensearch.xml")
      return fail_check("/opensearch.xml missing") unless File.file?(path)

      @checks += 1
      doc = REXML::Document.new(File.read(path))
      ns = { "os" => "http://a9.com/-/spec/opensearch/1.1/" }
      template = REXML::XPath.first(doc, "/os:OpenSearchDescription/os:Url/@template", ns)&.value
      fail_check("/opensearch.xml missing Url template") if template.nil? || template.empty?
    rescue REXML::ParseException => e
      fail_check("/opensearch.xml is not well-formed XML: #{e.message}")
    end

    def check_routes(catalog)
      catalog["items"].each do |item|
        check_landing_page(item)
        check_files(item)
      end
      check_latest_aliases(catalog)
    end

    def check_landing_page(item)
      path = File.join(@site_dir, item["url"], "index.html")
      return fail_check("landing page missing for #{item['slug']} at #{item['url']}") unless File.file?(path)

      @checks += 1
      html = File.read(path)
      fail_check("landing page for #{item['slug']} does not mention its identifier") unless html.include?(item["id"])

      item["files"].each do |file|
        unless html.include?("\"#{file['url']}\"")
          fail_check("landing page for #{item['slug']} does not link #{file['url']}")
        end
      end

      jsonld = html[/\<script type="application\/ld\+json"\>(.*?)\<\/script\>/m, 1]
      begin
        data = jsonld && JSON.parse(jsonld)
        fail_check("landing page for #{item['slug']} has no parseable JSON-LD") unless data.is_a?(Hash) && data.key?("@type")
      rescue JSON::ParserError
        fail_check("landing page for #{item['slug']} has malformed JSON-LD")
      end
    end

    def check_files(item)
      item["files"].each do |file|
        path = File.join(@site_dir, file["url"])
        fail_check("artifact missing for #{item['slug']}: #{file['url']}") unless File.file?(path)

        @checks += 1
      end
    end

    def check_latest_aliases(catalog)
      catalog["items"].group_by { |item| item["document_id"] }.each_value do |group|
        latest = group.find { |item| item["editions"].any? { |e| e["current"] && e["url"] == item["url"] } }
        alias_path = File.join(@site_dir, latest["latest_url"].delete_suffix("/"), "index.html")
        unless File.file?(alias_path)
          fail_check("latest alias missing for #{latest['document_id']} at #{latest['latest_url']}")
          next
        end

        @checks += 1
        html = File.read(alias_path)
        unless html.include?("url=#{latest['url']}")
          fail_check("latest alias for #{latest['document_id']} does not redirect to #{latest['url']}")
        end
      end
    end

    def fail_check(message)
      @failures << message
    end
  end
end
