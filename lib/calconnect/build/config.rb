module CalConnect
  module Build
    class Config
      attr_reader :site_dir, :canon_path, :bib_dir, :org, :registry_name,
                  :doc_types, :bib_formats

      def initialize(
        site_dir: "_site",
        canon_path: "cc",
        bib_dir: "relaton",
        org: "CalConnect",
        registry_name: "CalConnect Document Registry",
        doc_types: DocTypeRegistry.new.keys,
        bib_formats: %w[json yaml rxl]
      )
        @site_dir = site_dir
        @canon_path = canon_path
        @bib_dir = bib_dir
        @org = org
        @registry_name = registry_name
        @doc_types = doc_types
        @bib_formats = bib_formats
      end

      def registry = DocTypeRegistry.new

      def canon_dir
        File.join(site_dir, canon_path)
      end

      def bib_json_path
        File.join(bib_dir, "index.json")
      end

      def bib_yaml_dir
        File.join(bib_dir, "yaml")
      end

      def bib_rxl_dir
        File.join(bib_dir, "rxl")
      end

      def repopulating_doc_types
        doc_types - %w[public-review pending-publication]
      end

      def docker_image
        ENV["METANORMA_DOCKER"]
      end

      def docker?
        !docker_image.nil?
      end
    end
  end
end
