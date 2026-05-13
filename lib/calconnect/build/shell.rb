module CalConnect
  module Build
    class Shell
      def initialize(config)
        @config = config
      end

      def exec(*cmd, env: {})
        puts cmd.join(" ")
        full_cmd = env.empty? ? cmd : [env, *cmd]
        result = system(*full_cmd)
        raise "Command failed: #{cmd.join(" ")}" unless result
      end

      def bundle_exec(*cmd, gemfile: nil)
        if gemfile
          env = {"BUNDLE_GEMFILE" => gemfile}
          Bundler.with_unbundled_env do
            exec("bundle", "exec", *cmd, env: env)
          end
        else
          exec("bundle", "exec", *cmd)
        end
      end

      def metanorma_exec(*cmd)
        if @config.docker?
          exec("docker", "run", "-v", "#{Dir.pwd}:/metanorma", @config.docker_image, *cmd)
        else
          bundle_exec(*cmd, gemfile: "src-documents/Gemfile")
        end
      end

      def relaton_exec(*cmd)
        bundle_exec(*cmd, gemfile: "relaton.Gemfile")
      end
    end
  end
end
