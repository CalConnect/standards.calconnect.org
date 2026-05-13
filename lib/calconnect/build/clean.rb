require "fileutils"

module CalConnect
  module Build
    class Clean
      def initialize(config)
        @config = config
      end

      def all
        FileUtils.rm_rf(@config.bib_dir)
        FileUtils.rm_rf(@config.site_dir)
      end

      def bib
        FileUtils.rm_rf(@config.bib_dir)
      end
    end
  end
end
