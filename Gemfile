source "https://rubygems.org"

gem "jekyll", "~> 4.4"
gem "jekyll-calconnect-theme"
gem "metanorma-release", github: "metanorma/metanorma-release", tag: "v0.2.24"
gem "standards-registry", github: "metanorma/standards-registry"
gem "octokit", "~> 9.0"
gem "relaton-calconnect", "~> 2.1"

group :jekyll_plugins do
  gem "jekyll-asciidoc"
  gem "jekyll-vite", require: "jekyll/vite"
end

gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
gem "wdm", "~> 0.1.0" if Gem.win_platform?

group :test do
  gem "rspec", "~> 3.13"
  gem "json_schemer", "~> 2.0"
end
