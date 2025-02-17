# This is the Jekyll Gemfile.

source "https://rubygems.org"

gem "jekyll", "~> 4.4"
gem "minima", "~> 2.5.2"

# If you want to use GitHub Pages, remove the "gem "jekyll"" above and
# uncomment the line below. To upgrade, run `bundle update github-pages`.
# gem "github-pages", group: :jekyll_plugins

# If you have any plugins, put them here!
group :jekyll_plugins do
  gem "jekyll-feed", "~> 0.17.0"
  gem "jekyll-asciidoc"
  # gem "jekyll-paginate-v2"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Performance-booster for watching directories on Windows
gem "wdm", "~> 0.1.0" if Gem.win_platform?

group :development do
  gem "rubocop", "~> 1.72", require: false
  gem "rubocop-performance", "~> 1.24.0", require: false
end
