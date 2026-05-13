module CalConnect
  module Build
    class Submodules
      def initialize(config, shell)
        @config = config
        @shell = shell
      end

      def checkout
        @shell.exec("git", "submodule", "update", "--init")
      end

      def update
        @shell.exec("git", "submodule", "foreach", "git", "pull", "origin", "main")
      end
    end
  end
end
