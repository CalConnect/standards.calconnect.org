module CalConnect
  module Build
    class Jekyll
      def initialize(config, shell)
        @config = config
        @shell = shell
      end

      def build
        @shell.exec("npm", "run", "build")
        @shell.bundle_exec("jekyll", "build")
      end

      def serve
        @shell.bundle_exec("jekyll", "serve")
      end
    end
  end
end
