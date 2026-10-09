source "https://rubygems.org"

gem "metanorma-release", github: "metanorma/metanorma-release", tag: "v0.2.24"
# Registry engine: enrichment, schemas, validation and conformance harness.
gem "standards-registry", github: "metanorma/standards-registry"
gem "octokit", "~> 9.0"
gem "rake", "~> 13.2"
gem "relaton-calconnect", "~> 2.1"

gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem "wdm", "~> 0.1.0" if Gem.win_platform?

group :test do
  gem "rspec", "~> 3.13"
  gem "json_schemer", "~> 2.0"
end
