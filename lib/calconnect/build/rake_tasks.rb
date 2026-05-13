require "rake"

module CalConnect
  module Build
    class RakeTasks
      include Rake::DSL

      def self.install
        new.install
      end

      def initialize
        @config = Config.new
        @shell = Shell.new(@config)
        @jekyll = Jekyll.new(@config, @shell)
        @relaton = RelatonIndex.new(@config)
        @releases = Releases.new(@config, @shell)
        @metanorma = Metanorma.new(@config, @shell)
        @canonicalize = Canonicalize.new(@config, @shell)
        @submodules = Submodules.new(@config, @shell)
        @clean = Clean.new(@config)
      end

      def install
        install_clean_tasks
        install_jekyll_tasks
        install_release_tasks
        install_relaton_tasks
        install_metanorma_tasks
        install_submodule_tasks
        install_pipeline_tasks
      end

      private

      def install_clean_tasks
        desc "Clean all generated files"
        task :clean do
          @clean.all
        end

        desc "Clean Relaton build artifacts"
        task :"clean:relaton" do
          @clean.bib
        end
      end

      def install_jekyll_tasks
        desc "Build Jekyll site"
        task :jekyll do
          @jekyll.build
        end

        desc "Serve Jekyll site"
        task :serve do
          @jekyll.serve
        end

        desc "Install Jekyll dependencies"
        task :"prep:jekyll" do
          @shell.exec("bundle", "install")
        end
      end

      def install_release_tasks
        desc "Download released documents into _site/cc/"
        task :"releases:fetch" do
          @releases.fetch
        end
      end

      def install_relaton_tasks
        desc "Build Relaton bibliography index and _data/documents.json"
        task :"relaton:build" do
          @relaton.build
        end
      end

      def install_metanorma_tasks
        desc "Install Metanorma dependencies"
        task :"prep:metanorma" do
          @shell.bundle_exec("install", gemfile: "src-documents/Gemfile")
        end

        desc "Build all Metanorma documents (serial)"
        task :"metanorma:build" do
          @metanorma.build_all
        end

        desc "Build all Metanorma documents (parallel)"
        task :"metanorma:build_parallel" do
          @metanorma.build_all(parallel: true)
        end

        desc "Repopulate Metanorma YAML files for all doc types"
        task :"metanorma:repopulate" do
          @metanorma.repopulate_all_yamls
        end

        desc "Repopulate Metanorma YAML files (parallel)"
        task :"metanorma:repopulate_parallel" do
          @metanorma.repopulate_all_yamls(parallel: true)
        end

        desc "Canonicalize document artifact paths"
        task :canonicalize do
          @canonicalize.run
        end
      end

      def install_submodule_tasks
        desc "Checkout git submodules"
        task :"submodules:checkout" do
          @submodules.checkout
        end

        desc "Update git submodules"
        task :"submodules:update" do
          @submodules.update
        end
      end

      def install_pipeline_tasks
        desc "Install all dependencies (submodules + Ruby + Node)"
        task :prep => [:"submodules:checkout", :"prep:jekyll", :"prep:metanorma"]

        desc "Build entire site from released artifacts"
        task :"build:from_releases" => [:"releases:fetch", :"relaton:build", :jekyll]

        desc "Build everything (submodule-based, parallel)"
        task :"build:all" => [:"metanorma:build_parallel", :"relaton:build", :jekyll]

        desc "Update documents (pull submodules + repopulate YAMLs)"
        task :"docs:update" => [:"submodules:update", :"metanorma:repopulate_parallel"]
      end
    end
  end
end
