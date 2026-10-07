# frozen_string_literal: true

require "digest"
require "json"

module Registry
  # CI-grade semantic checks over the emitted catalog
  # (TODO.improvements/02,03,04,10):
  #
  #   projection  — top-level fields recomputed from `bibliographic`;
  #                 any independent edit fails the build
  #   pipeline    — registry/catalog.json equals a fresh in-memory
  #                 enrichment of the producer outputs
  #   files       — one representation per format, sorted, checksums and
  #                 byte sizes verified against the files on disk
  #   urls        — canonical URLs reconstruct from the index alone and
  #                 are unique
  #   editions    — exactly one current edition per document group
  class Consistency
    MAX_REPORTED = 20

    attr_reader :problems

    def initialize(config)
      @config = config
      @problems = []
    end

    def run
      return self unless File.exist?(@config.catalog_path)

      catalog = Catalog.from_file(@config.catalog_path)
      check_projection(catalog)
      check_pipeline(catalog)
      check_files(catalog)
      check_urls(catalog)
      check_editions(catalog)
      check_search_index(catalog)
      self
    end

    def ok?
      problems.empty?
    end

    private

    def check_projection(catalog)
      catalog.items.each do |item|
        bib = item["bibliographic"] || {}
        compare_item(item, bib) unless bib.empty?
      end
    end

    def compare_item(item, bib)
      slug = item["slug"]
      add("items[#{slug}].id", item["id"], Projection.identifier(bib, {})) if bib["docidentifier"]
      add("items[#{slug}].title", item["title"], Projection.title(bib, {})) if bib["title"]
      add("items[#{slug}].abstract", item["abstract"], Projection.abstract(bib))
      add("items[#{slug}].doctype", item["doctype"], Projection.doctype(bib, {})) if bib.dig("ext", "doctype")
      add("items[#{slug}].stage", item["stage"], Projection.stage(bib, {})) if bib.dig("status", "stage")
      add("items[#{slug}].date", item["date"], Projection.date(bib, {})) if bib["date"]
      add("items[#{slug}].language", item["language"], Projection.language(bib))
      add("items[#{slug}].license", item["license"], Projection.license(bib, @config.license_default))
      add("items[#{slug}].copyright", item["copyright"], Projection.copyright(bib))
      add("items[#{slug}].authors", item["authors"], Projection.authors(bib))
      add("items[#{slug}].committee", item["committee"], Projection.committee(bib))
      add("items[#{slug}].relaton_schema_version", item["relaton_schema_version"],
          Projection.relaton_schema_version(bib))
      add("items[#{slug}].display_category_slug", item["display_category_slug"],
          @config.display_category_for(item["doctype"])&.fetch("slug", nil))
      add("items[#{slug}].doctype_class", item["doctype_class"],
          item["doctype"] && "type-#{item['doctype'].downcase}")
      add("items[#{slug}].stage_css", item["stage_css"], item["stage"].gsub(/\s+/, "-"))
    end

    def check_pipeline(catalog)
      return unless File.exist?(@config.relaton_index_path)

      fresh = Enricher.new(config: @config).build.catalog
      diff(fresh.to_h, catalog.to_h, "catalog")
    end

    def check_files(catalog)
      catalog.items.each do |item|
        path = "items[#{item['slug']}].files"
        formats = item["files"].map { |f| f["format"] }
        add_problem("#{path}: duplicate format entries #{formats.tally.select { |_, n| n > 1 }.keys}") if
          formats.length != formats.uniq.length
        ranked = item["files"].sort_by { |f| [format_rank(f["format"]), f["format"]] }
        add_problem("#{path}: not in canonical order") if item["files"] != ranked

        item["files"].each do |file|
          check_file(item, file)
        end
      end
    end

    def check_file(item, file)
      slug = item["slug"]
      rel = file["url"].delete_prefix("#{@config.docs_prefix}/")
      abs = File.join(@config.output_dir, rel)
      unless File.file?(abs)
        add_problem("items[#{slug}].files: #{file['url']} missing on disk")
        return
      end

      add("items[#{slug}].files[#{file['format']}].bytes", file["bytes"], File.size(abs))
      add("items[#{slug}].files[#{file['format']}].sha256", file["sha256"],
          Digest::SHA256.file(abs).hexdigest)
      add("items[#{slug}].files[#{file['format']}].media_type", file["media_type"],
          MediaTypes.for(file["format"]))
    end

    def check_urls(catalog)
      seen = Hash.new(0)
      catalog.items.each do |item|
        seen[item["url"]] += 1
        add("items[#{item['slug']}].latest_url", item["latest_url"],
            Urls.latest_path(item))
        if item["urn"] && !item["urn"].start_with?("urn:#{@config.urn_namespace}:")
          add_problem("items[#{item['slug']}].urn not in the instance namespace: #{item['urn']}")
        end
      end
      seen.each do |url, count|
        next unless count > 1

        add_problem("items: #{count} items share landing URL #{url} — source repos must use distinct slugs")
      end
    end

    def check_editions(catalog)
      catalog.items.group_by { |item| item["document_id"] }.each_value do |group|
        latest = Urls.latest(group)
        group.each do |item|
          current = item["editions"].select { |e| e["current"] }
          if current.length != 1
            add_problem("items[#{item['slug']}].editions: expected exactly 1 current, got #{current.length}")
            next
          end
          add("items[#{item['slug']}].editions[current].url", current.first["url"], latest["url"])
        end
      end
    end

    def check_search_index(catalog)
      return unless File.exist?(@config.search_index_path)

      fresh = SearchIndex.build(catalog.items,
                                generated_at: catalog.meta[:generated_at],
                                org: catalog.meta[:org])
      stored = JSON.parse(File.read(@config.search_index_path))
      diff(fresh.to_h, stored, "search-index")
    end

    def add(label, actual, expected)
      return if actual == expected

      add_problem("#{label}: #{actual.inspect} != recomputed #{expected.inspect}")
    end

    def add_problem(message)
      @problems << message
    end

    def format_rank(format)
      Enricher::FORMAT_ORDER.index(format) || Enricher::FORMAT_ORDER.length
    end

    def diff(expected, actual, label)
      out = []
      deep_diff(expected, actual, label, out)
      out.first(MAX_REPORTED).each { |line| add_problem(line) }
      add_problem("#{label}: #{out.length - MAX_REPORTED} more differences") if out.length > MAX_REPORTED
    end

    def deep_diff(expected, actual, path, out)
      return out << "#{path}: #{expected.inspect} != #{actual.inspect}" unless comparable?(expected, actual)

      if expected.is_a?(Hash)
        (expected.keys | actual.keys).each do |key|
          deep_diff(expected[key], actual[key], "#{path}.#{key}", out)
        end
      elsif expected.is_a?(Array)
        if expected.length != actual.length
          out << "#{path}: length #{expected.length} != #{actual.length}"
        else
          expected.each_with_index { |value, i| deep_diff(value, actual[i], "#{path}[#{i}]", out) }
        end
      elsif expected != actual
        out << "#{path}: #{expected.inspect} != #{actual.inspect}"
      end
    end

    def comparable?(expected, actual)
      expected.class == actual.class ||
        (expected.is_a?(Hash) && actual.is_a?(Hash)) ||
        (expected.is_a?(Array) && actual.is_a?(Array))
    end
  end
end
