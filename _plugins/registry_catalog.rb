# frozen_string_literal: true

# Reference-renderer bridge for the registry contract: reads the neutral
# registry/ handoff (catalog + search index) — never _data/ or producer
# paths — and exposes it to Liquid, serves /catalog.json and
# /search-index.json from the site root, and generates the routes the
# conformance profile requires: versioned document landing pages,
# "latest" aliases and legacy redirects (TODO.improvements/03, 12).
#
# A non-Jekyll frontend implements the same behaviour against the same
# directory and passes the same conformance suite; this plugin holds no
# private advantages.

require "json"

module Jekyll
  class RegistryAssetFile < StaticFile
    def initialize(site, registry_dir, file_name, dest_name: nil)
      @registry_file_name = file_name
      @dest_name = dest_name || file_name
      super(site, site.source, registry_dir, file_name)
    end

    def destination(dest)
      Jekyll.sanitized_path(dest, @dest_name)
    end

    def copy_file(dest_path)
      FileUtils.cp(path, dest_path)
    end
  end

  class GeneratedPage < PageWithoutAFile
    def initialize(site, dir, layout, name = "index.html", data = {})
      @site = site
      @base = site.source
      @dir = dir
      @name = name
      process(name)
      self.data = { "layout" => layout }.merge(data)
      self.content = ""
    end
  end

  # A page emitted verbatim (no layout, no conversion): citation files,
  # checksum sidecars.
  class RawPage < PageWithoutAFile
    def initialize(site, dir, name, content)
      @site = site
      @base = site.source
      @dir = dir
      @name = name
      process(name)
      self.data = {}
      self.content = content
    end
  end

  class RegistryCatalogGenerator < Generator
    priority :high

    def generate(site)
      catalog = load_catalog(site)
      return if catalog.nil?

      site.data["registry_catalog"] = catalog
      site.data["registry_search_index"] = load_json(site, registry_dir(site), "search-index.json")

      serve_endpoints(site)
      serve_citation_exports(site)
      generate_catalog_checksum(site)
      if html_enabled?(site)
        generate_document_pages(site, catalog)
        generate_latest_aliases(site, catalog)
        generate_legacy_redirects(site, catalog)
      end
    end

    private

    # Headless instances (registry.features.html: false) serve the data
    # endpoints only — HTML routes are optional in the conformance profile
    # (TODO.improvements/12).
    def html_enabled?(site)
      site.config.dig("registry", "features", "html") != false
    end

    def registry_dir(site)
      site.config.dig("registry", "dir") || "registry"
    end

    def load_catalog(site)
      load_json(site, registry_dir(site), "catalog.json")
    end

    def load_json(site, dir, name)
      path = site.in_source_dir(dir, name)
      return nil unless File.exist?(path)

      JSON.parse(File.read(path))
    end

    def serve_endpoints(site)
      site.static_files << RegistryAssetFile.new(site, registry_dir(site), "catalog.json")
      site.static_files << RegistryAssetFile.new(site, registry_dir(site), "search-index.json")
    end

    # Citation exports (ISO 690, BibTeX, RIS, CSL — generated from the
    # contract by scripts/generate-citations.mjs via relaton-ts) served
    # at /docs/{slug}.{ext}, alongside the artifacts.
    def serve_citation_exports(site)
      dir = File.join(registry_dir(site), "citations")
      return unless File.directory?(site.in_source_dir(dir))

      Dir.glob(site.in_source_dir(dir, "*")).sort.each do |path|
        name = File.basename(path)
        site.static_files << RegistryAssetFile.new(
          site, File.join(registry_dir(site), "citations"), name,
          dest_name: File.join("docs", name)
        )
      end
    end

    def generate_catalog_checksum(site)
      require "digest"
      source = File.join(registry_dir(site), "catalog.json")
      digest = Digest::SHA256.file(source).hexdigest
      site.pages << RawPage.new(site, "/", "catalog.json.sha256", "#{digest}  catalog.json\n")
    end

    def generate_document_pages(site, catalog)
      catalog["items"].each do |item|
        dir = item["url"].delete_suffix("/")
        site.pages << GeneratedPage.new(site, dir, "document", "index.html",
                                        { "doc" => item, "title" => item["id"],
                                          "iso690" => iso690_for(site, item) })
      end
    end

    def iso690_for(site, item)
      path = site.in_source_dir(registry_dir(site), "citations", "#{item['slug']}.iso690.txt")
      File.exist?(path) ? File.read(path).strip : nil
    end

    def generate_latest_aliases(site, catalog)
      catalog["items"]
        .group_by { |item| item["document_id"] }
        .each_value do |group|
          current = group.map { |item| item["editions"].detect { |e| e["current"] } }.compact.first
          next if current.nil?

          latest = group.find { |item| item["url"] == current["url"] }
          dir = latest["latest_url"].delete_suffix("/")
          site.pages << GeneratedPage.new(site, dir, "redirect", "index.html",
                                          { "destination" => latest["url"], "canonical" => latest["url"] })
        end
    end

    def generate_legacy_redirects(site, catalog)
      legacy_prefixes(site).each do |prefix|
        catalog["items"].each do |item|
          item["files"].each do |file|
            next unless file["format"] == "html"

            name = File.basename(file["url"])
            site.pages << GeneratedPage.new(site, "/#{prefix}", "redirect", name,
                                            { "destination" => file["url"], "canonical" => file["url"] })          end
        end
      end
    end

    def legacy_prefixes(site)
      Array(site.config.dig("registry", "legacy_prefixes"))
    end
  end
end
