module CalConnect
  module Build
    class Metanorma
      def initialize(config, shell)
        @config = config
        @shell = shell
      end

      def build(doc_type)
        @shell.metanorma_exec(
          "metanorma", "site", "generate",
          "-o", File.join(@config.site_dir, doc_type),
          "-c", "./src-documents/metanorma-#{doc_type}.yml"
        )
      end

      def build_all(parallel: false)
        if parallel
          @config.doc_types.map { |dt| Thread.new { build(dt) } }.each(&:join)
        else
          @config.doc_types.each { |dt| build(dt) }
        end
      end

      def repopulate_yaml(doc_type)
        @shell.exec(
          "scripts/repopulate-metanorma-yaml",
          "src-documents",
          "src-documents/metanorma-#{doc_type}.yml",
          env: {
            "DOC_TYPE" => doc_type,
            "DOC_CLASS" => "cc",
            "BASE_DIR" => "src-documents",
            "EMPTY_ADOC" => "empty_index.adoc"
          }
        )
      end

      def repopulate_all_yamls(parallel: false)
        types = @config.repopulating_doc_types
        if parallel
          types.map { |dt| Thread.new { repopulate_yaml(dt) } }.each(&:join)
        else
          types.each { |dt| repopulate_yaml(dt) }
        end
      end
    end
  end
end
