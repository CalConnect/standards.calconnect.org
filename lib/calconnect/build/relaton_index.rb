require "fileutils"
require "json"

module CalConnect
  module Build
    class RelatonIndex
      CHANNEL_DOCTYPE_MAP = {
        "standards" => "standard",
        "reports" => "report",
        "specifications" => "specification",
        "directives" => "directive",
        "advisories" => "advisory",
        "admin" => "administrative",
        "guides" => "guide",
        "public-review" => "public-review",
        "pending-publication" => "pending-publication",
        "amendments" => "amendment",
        "technical-corrigenda" => "technical-corrigendum",
      }.freeze

      def initialize(config)
        @config = config
      end

      def build
        items = build_from_aggregate_index
        verify!(items)
        write_data_file(items)
        build_relaton_output
        puts "Document index: #{items.length} documents → _data/documents.json"
      end

      private

      def aggregate_index_path
        File.join(@config.canon_dir, "index.json")
      end

      def build_from_aggregate_index
        unless File.exist?(aggregate_index_path)
          abort "No document data found. Expected aggregate index at #{aggregate_index_path}"
        end

        raw = JSON.parse(File.read(aggregate_index_path))
        docs = raw["documents"] || []
        docs.map { |doc| flatten(doc) }
      end

      def flatten(doc)
        channels = doc["channels"] || []
        doctype = derive_doctype(channels)
        slug = doc["id"].to_s.downcase.gsub(%r{[^a-z0-9]+}, "-").gsub(/^-+|-+$/, "")
        formats = doc["formats"] || []
        file_exts = (doc["files"] || []).map { |f| File.extname(f["name"]).delete_prefix(".") }
        all_fmts = (formats + file_exts).uniq
        release_date = doc.dig("source", "releaseDate")
        date = release_date&.split("T")&.first

        {
          "slug" => slug,
          "id" => doc["id"],
          "title" => doc["title"].to_s,
          "stage" => (doc["stage"] || "published").to_s.downcase,
          "stage_css" => (doc["stage"] || "published").to_s.downcase.tr(" ", "-"),
          "doctype" => doctype,
          "doctype_class" => doctype.tr(" ", "-"),
          "edition" => doc["edition"],
          "date" => date,
          "channels" => channels,
          "has_html" => all_fmts.include?("html"),
          "has_pdf" => all_fmts.include?("pdf"),
          "has_xml" => all_fmts.include?("xml"),
          "has_rxl" => all_fmts.include?("rxl"),
        }
      end

      def derive_doctype(channels)
        return "" unless channels.is_a?(Array) && channels.any?
        category = channels.first.split("/").last
        CHANNEL_DOCTYPE_MAP.fetch(category, category)
      end

      def verify!(items)
        if items.empty?
          abort "Build produced 0 documents — aborting to prevent empty deploy. Check aggregate output."
        end
      end

      def write_data_file(items)
        FileUtils.mkdir_p("_data")
        File.write("_data/documents.json", JSON.pretty_generate({ "items" => items }))
      end

      def build_relaton_output
        require "relaton/calconnect"
        require "yaml"

        rxl_files = Dir.glob(File.join(@config.canon_dir, "*.rxl"))
        if rxl_files.empty?
          puts "  (No RXL files for relaton/ bibliography — skipped)"
          return
        end

        items = rxl_files.filter_map do |path|
          Relaton::Calconnect::Item.from_xml(File.read(path)).to_h
        rescue => e
          warn "  Skip #{File.basename(path)}: #{e.message}"
          nil
        end

        FileUtils.mkdir_p(@config.bib_dir)

        index = { "root" => { "title" => @config.registry_name, "items" => items } }
        File.write(File.join(@config.bib_dir, "index.json"), JSON.pretty_generate(index))
        File.write(File.join(@config.bib_dir, "index.yaml"), YAML.dump(JSON.parse(JSON.generate(index))))

        dest = File.join(@config.site_dir, @config.bib_dir)
        FileUtils.rm_rf(dest)
        FileUtils.cp_r(@config.bib_dir, dest)

        puts "  Relaton bibliography: #{items.length} items → #{@config.bib_dir}/"
      rescue LoadError
        puts "  (relaton gem not available — bibliography skipped)"
      end
    end
  end
end
