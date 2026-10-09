source "https://rubygems.org"

gem "metanorma-release", github: "metanorma/metanorma-release", tag: "v0.2.24"
# Registry engine: enrichment, schemas, validation and conformance harness.
# Pinned to the first tagged release (2026-10-09); bump via tagged releases.
gem "standards-registry", github: "metanorma/standards-registry", tag: "v1.0.0"
gem "octokit", "~> 9.0"
gem "rake", "~> 13.2"
gem "relaton-calconnect", "~> 2.1"

gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem "wdm", "~> 0.1.0" if Gem.win_platform?

group :test do
  gem "rspec", "~> 3.13"
  gem "json_schemer", "~> 2.0"
end
