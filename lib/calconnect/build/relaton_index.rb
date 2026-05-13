require "fileutils"
require "json"
require "yaml"
require "relaton/calconnect"

module CalConnect
  module Build
    class RelatonIndex
      def initialize(config)
        @config = config
      end

      def build
        items = parse_rxl_files
        if items.empty?
          warn "No RXL files found in #{@config.canon_dir}"
          write_empty_data
          return
        end

        FileUtils.mkdir_p(@config.bib_dir)
        write_json_index(items)
        write_yaml_index(items)
        copy_to_site
        write_data_file(items)
        puts "Relaton index: #{items.length} documents → #{@config.bib_dir}/"
      end

      private

      def parse_rxl_files
        Dir.glob(File.join(@config.canon_dir, "*.rxl")).filter_map do |path|
          Relaton::Calconnect::Item.from_xml(File.read(path)).to_h
        rescue => e
          warn "  Skip #{File.basename(path)}: #{e.message}"
          nil
        end
      end

      def write_json_index(items)
        path = File.join(@config.bib_dir, "index.json")
        File.write(path, JSON.pretty_generate(wrap(items)))
      end

      def write_yaml_index(items)
        plain = JSON.parse(JSON.generate(wrap(items)))
        path = File.join(@config.bib_dir, "index.yaml")
        File.write(path, YAML.dump(plain))
      end

      def wrap(items)
        { "root" => { "title" => @config.registry_name, "items" => items } }
      end

      def copy_to_site
        dest = File.join(@config.site_dir, @config.bib_dir)
        FileUtils.rm_rf(dest)
        FileUtils.cp_r(@config.bib_dir, dest)
      end

      def write_data_file(items)
        formats_by_slug = discover_formats
        flat = items.map { |item| flatten_item(item, formats_by_slug) }
        FileUtils.mkdir_p("_data")
        File.write("_data/documents.json", JSON.pretty_generate({ "items" => flat }))
      end

      def write_empty_data
        FileUtils.mkdir_p("_data")
        File.write("_data/documents.json", JSON.pretty_generate({ "items" => [] }))
      end

      def discover_formats
        canon = @config.canon_dir
        return {} unless Dir.exist?(canon)

        Dir.glob(File.join(canon, "*")).each_with_object({}) do |f, hash|
          next unless File.file?(f)
          base = File.basename(f)
          name, ext = base.split(".", 2)
          next unless ext
          slug = name.downcase.gsub(%r{[^a-z0-9]+}, "-").gsub(/^-+|-+$/, "")
          (hash[slug] ||= []) << ext
        end
      end

      def flatten_item(item, formats_by_slug)
        primary = primary_docid(item)
        slug = primary.downcase.gsub(%r{[^a-z0-9]+}, "-").gsub(/^-+|-+$/, "")
        fmts = formats_by_slug[slug] || []
        stage = item.dig("status", "stage", "content") || ""
        stage_abbr = item.dig("status", "stage", "abbreviation") || stage
        doctype = item.dig("ext", "doctype", "content") || ""
        edition = item.dig("edition", "content")
        dates = item["date"]
        date = dates ? (dates.find { |d| d["type"] == "published" }&.dig("at") || dates.first&.dig("at")) : nil
        abstracts = item["abstract"]
        abstract = abstracts&.first&.dig("content")&.gsub(%r{<[^>]+>}, "")&.[](0, 200) || ""

        {
          "slug" => slug,
          "id" => primary,
          "title" => title_text(item),
          "stage" => stage.downcase,
          "stage_css" => stage.downcase.gsub(" ", "-"),
          "stage_abbr" => stage_abbr.to_s,
          "doctype" => doctype.downcase,
          "doctype_class" => doctype.downcase.gsub(" ", "-"),
          "edition" => edition,
          "date" => date,
          "abstract" => abstract,
          "has_html" => fmts.include?("html"),
          "has_pdf" => fmts.include?("pdf"),
          "has_xml" => fmts.include?("xml"),
          "has_rxl" => fmts.include?("rxl")
        }
      end

      def title_text(item)
        titles = item["title"]
        return "" unless titles.is_a?(Array)
        t = titles.find { |t| t["type"] == "main" } || titles.first
        t&.dig("content") || ""
      end

      def primary_docid(item)
        ids = item["docidentifier"]
        primary = ids&.find { |d| d["primary"] } || ids&.first
        primary&.dig("content") || item["id"].to_s
      end
    end
  end
end
