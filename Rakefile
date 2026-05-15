# frozen_string_literal: true

require "fileutils"

desc "Aggregate releases and build document index"
task :fetch do
  sh "bundle exec metanorma-release aggregate"
end

desc "Build entire site (fetch + Jekyll)"
task build: :fetch do
  sh "npm run build"
  sh "bundle exec jekyll build"
end

desc "Build Jekyll site (assumes fetch already done)"
task :jekyll do
  sh "npm run build"
  sh "bundle exec jekyll build"
end

desc "Serve the built site locally"
task :serve do
  sh "bundle exec jekyll serve"
end

desc "Remove all build artifacts"
task :clean do
  FileUtils.rm_rf("_site")
end
