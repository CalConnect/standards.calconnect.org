require "fileutils"
require "json"
require "open-uri"
require "tempfile"

module CalConnect
  module Build
    class Releases
      EDITION_SUFFIX = /-ed\d+(\.\d+)?(-[a-z0-9]+)?\./

      def initialize(config, shell)
        @config = config
        @shell = shell
      end

      def fetch(*repos)
        repos = discover_repos if repos.empty?
        abort "No repos found. Add the 'metanorma-release' topic to repos first." if repos.empty?

        FileUtils.mkdir_p(out_dir)

        total_files = 0
        total_rxls = 0

        repos.each do |repo|
          count, rxls = fetch_repo(repo)
          total_files += count
          total_rxls += rxls
          puts "  OK   #{repo} (#{count} files)"
        end

        FileUtils.touch(File.join(out_dir, ".canonicalized"))

        puts "Done. #{total_files} files (#{total_rxls} RXL) → #{out_dir}/"
      end

      private

      def discover_repos
        org = ENV.fetch("GITHUB_ORG", "CalConnect")
        puts "Discovering repos with topic 'metanorma-release' in #{org}..."
        output = `gh api "search/repositories?q=topic:metanorma-release+org:#{org}&per_page=100" --jq '.items[].name' 2>/dev/null`
        return [] unless $?.success?
        output.lines.map(&:strip).reject(&:empty?)
      end

      def fetch_repo(repo)
        org = ENV.fetch("GITHUB_ORG", "CalConnect")
        raw = `gh api repos/#{org}/#{repo}/releases --paginate -q '.[]' 2>/dev/null`
        return [0, 0] unless $?.success?

        # gh -q '.[]' outputs each release as a compact JSON line
        releases = raw.lines.map { |l| JSON.parse(l.strip) rescue nil }.compact

        files = 0
        rxls = 0

        Dir.mktmpdir do |tmpdir|
          releases.each do |release|
            zip_asset = release["assets"]&.find { |a| a["name"].end_with?(".zip") }
            next unless zip_asset

            tag = release["tag_name"].gsub("/", "_")
            zip_path = File.join(tmpdir, "#{repo}-#{tag}.zip")
            URI.open(zip_asset["browser_download_url"]) { |r| File.binwrite(zip_path, r.read) }

            extract_dir = File.join(tmpdir, "#{repo}-#{tag}")
            FileUtils.mkdir_p(extract_dir)
            system("unzip", "-qn", zip_path, "-d", extract_dir)

            Dir.glob(File.join(extract_dir, "*")).each do |f|
              next unless File.file?(f)
              clean = File.basename(f).gsub(EDITION_SUFFIX, ".")
              FileUtils.cp(f, File.join(out_dir, clean))
              files += 1
              rxls += 1 if clean.end_with?(".rxl")
            end
          end
        end

        [files, rxls]
      end

      def out_dir
        @config.canon_dir
      end
    end
  end
end
