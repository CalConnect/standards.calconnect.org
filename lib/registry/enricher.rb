# frozen_string_literal: true

require "digest"
require "json"
require "time"

module Registry
  # Post-aggregation enrichment (TODO.improvements/02,04,06,10): reads the
  # producer outputs (relaton/index.json + index.json + artifact files)
  # and emits the renderer-neutral handoff — registry/catalog.json,
  # registry/search-index.json and registry/backfill.json. The producer
  # is never modified, and this class contains no instance specifics.
  class Enricher
    FORMAT_ORDER = %w[html pdf xml doc docx odt epub rxl json txt adoc].freeze

    Result = Struct.new(:catalog, :search_index, :backfill, keyword_init: true)

    def initialize(config:, output_dir: nil)
      @config = config
      @output_dir = output_dir || config.output_dir
      @backfill = Backfill.new
      @file_claims = Hash.new { |h, k| h[k] = [] }
    end

    def build
      items = build_items(load_producer_items)
      items = deduplicate(items)
      attach_urls_and_editions(items)
      record_cross_item_issues(items)

      catalog = Catalog.new(meta: catalog_meta, items: items)
      search = SearchIndex.build(items, generated_at: @generated_at, org: @config.org)
      Result.new(catalog: catalog, search_index: search, backfill: @backfill)
    end

    def run
      result = build
      result.catalog.write(@config.catalog_path)
      result.search_index.write(@config.search_index_path)
      @backfill.write(@config.backfill_path, generated_at: @generated_at)
      result
    end

    private

    def load_producer_items
      relaton = JSON.parse(File.read(@config.relaton_index_path))
      items = relaton.dig("root", "items") || []
      raw_index_path = File.join(@output_dir, "index.json")
      @generated_at =
        if File.exist?(raw_index_path)
          JSON.parse(File.read(raw_index_path))["generatedAt"]
        end
      @generated_at ||= Time.now.utc.iso8601
      items
    end

    def build_items(raw_items)
      raw_items.filter_map { |raw| build_item(raw) }
    end

    def build_item(raw)
      bib = raw["bibliographic"] || {}
      slug = raw["id"].to_s
      stage = Projection.stage(bib, raw)
      doctype = Projection.doctype(bib, raw)
      category = @config.display_category_for(doctype)

      item = {
        "slug" => slug,
        "document_id" => Projection.document_id(slug),
        "id" => Projection.identifier(bib, raw),
        "title" => Projection.title(bib, raw),
        "abstract" => Projection.abstract(bib),
        "doctype" => doctype,
        "stage" => stage,
        "edition" => blank_to_nil(raw["edition"]),
        "date" => Projection.date(bib, raw),
        "year" => nil,
        "language" => Projection.language(bib),
        "license" => Projection.license(bib, @config.license_default),
        "copyright" => Projection.copyright(bib),
        "authors" => Projection.authors(bib),
        "committee" => Projection.committee(bib),
        "channels" => raw["channels"] || [],
        "urn" => nil,
        "url" => nil,
        "latest_url" => nil,
        "stage_css" => stage.gsub(/\s+/, "-"),
        "doctype_class" => doctype.nil? ? nil : "type-#{doctype.downcase}",
        "display_category" => category && category["name"],
        "display_category_slug" => category && category["slug"],
        "relaton_schema_version" => Projection.relaton_schema_version(bib),
        "files" => build_files(raw),
        "bibliographic" => bib.empty? ? nil : bib,
        "provenance" => provenance(raw),
        "editions" => [],
      }
      record_field_gaps(item)
      item
    end

    def attach_urls_and_editions(items)
      items.each { |item| item["year"] = item["date"]&.slice(0, 4) }
      items.group_by { |item| item["document_id"] }.each_value do |group|
        group.each do |item|
          item["url"] = Urls.landing_path(item, group, @config.url_scheme)
          item["latest_url"] = Urls.latest_path(item)
          item["urn"] = build_urn(item)
        end
        latest = Urls.latest(group)
        group.each do |item|
          item["editions"] = group.map { |g| edition_entry(g, g.equal?(latest)) }
        end
      end
    end

    # Two releases can carry byte-identical metadata (the same legacy
    # document published by two repos). Keep one deterministically —
    # lowest source_repository — while preserving the producer's item
    # order elsewhere, and record the dropped twins.
    def deduplicate(items)
      groups = items.group_by { |item| [item["slug"], item["edition"], item["date"]] }
      items.filter_map do |item|
        group = groups[[item["slug"], item["edition"], item["date"]]]
        next item if group.length == 1

        keeper = group.min_by { |i| i["provenance"]["source_repository"].to_s }
        next nil unless item.equal?(keeper)

        twins = group.reject { |i| i.equal?(keeper) }
                     .map { |i| i["provenance"]["source_repository"] }.uniq
        @backfill.add("duplicate_item", item["slug"],
                      "identical metadata also published by #{twins.join(', ')} — kept the release from #{keeper['provenance']['source_repository']}")
        item
      end
    end

    def edition_entry(item, current)
      {
        "edition" => item["edition"],
        "date" => item["date"],
        "year" => item["year"],
        "stage" => item["stage"],
        "slug" => item["slug"],
        "url" => item["url"],
        "current" => current,
      }
    end

    def build_urn(item)
      return nil if @config.urn_namespace.nil? || @config.urn_namespace.empty?

      tail = item["year"] || item["edition"]
      return nil if tail.nil?

      "urn:#{@config.urn_namespace}:#{item['document_id']}:#{tail}"
    end

    def build_files(raw)
      files = Array(raw["files"]).filter_map do |f|
        next nil if f.nil?

        path = f["path"].to_s
        abs = File.join(@output_dir, path)
        unless File.file?(abs)
          @backfill.add("missing_file", raw["id"], path)
          next nil
        end

        @file_claims[path] << raw["id"]
        {
          "format" => f["format"],
          "name" => f["name"] || File.basename(path),
          "media_type" => MediaTypes.for(f["format"]),
          "bytes" => File.size(abs),
          "sha256" => Digest::SHA256.file(abs).hexdigest,
          "url" => Urls.file_url(path, @config.docs_prefix),
        }
      end
      files.sort_by { |f| [format_rank(f["format"]), f["format"]] }
    end

    def format_rank(format)
      FORMAT_ORDER.index(format) || FORMAT_ORDER.length
    end

    def provenance(raw)
      source = raw["source"] || {}
      {
        "source" => source.empty? ? "local" : "release",
        "source_repository" =>
          source["owner"] && source["repo"] ? "#{source['owner']}/#{source['repo']}" : nil,
        "release_tag" => source["tag"],
        "release_url" => source["releaseUrl"],
        "release_date" => normalize_time(source["releaseDate"]),
        "built_at" => @generated_at,
        "generator" => @config.generator_label,
      }.compact
    end

    def record_field_gaps(item)
      slug = item["slug"]
      @backfill.add("missing_language", slug) if item["language"].nil?
      @backfill.add("missing_license", slug) if item["license"].nil?
      @backfill.add("missing_abstract", slug) if item["abstract"].nil?
      @backfill.add("missing_date", slug) if item["date"].nil?
    end

    def record_cross_item_issues(items)
      @file_claims.each do |path, slugs|
        next unless slugs.length > 1

        @backfill.add("file_collision", path,
                      "claimed by: #{slugs.uniq.join(', ')} — flat routing overwrote one edition; needs distinct filenames in the source repos")
      end
    end

    def catalog_meta
      {
        generated_at: @generated_at,
        org: @config.org,
        urn_namespace: @config.urn_namespace,
        url_scheme: @config.url_scheme,
        generator: @config.generator_label,
      }
    end

    def normalize_time(value)
      return nil if value.nil?

      Time.parse(value.to_s).utc.iso8601
    rescue ArgumentError
      nil
    end

    def blank_to_nil(value)
      value.nil? || value.to_s.strip.empty? ? nil : value.to_s
    end
  end
end
