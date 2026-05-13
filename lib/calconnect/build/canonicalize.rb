module CalConnect
  module Build
    class Canonicalize
      def initialize(config, shell)
        @config = config
        @shell = shell
      end

      def run
        return if canonicalized?

        @config.doc_types.each do |doc_type|
          @shell.exec(
            "scripts/canonicalize-document-paths",
            env: {
              "PUBLIC_PATH" => @config.canon_path,
              "SITE_SUB_DIR" => doc_type
            }
          )
        end

        FileUtils.touch(marker_path)
      end

      def canonicalized?
        File.exist?(marker_path)
      end

      private

      def marker_path
        File.join(@config.canon_dir, ".canonicalized")
      end
    end
  end
end
