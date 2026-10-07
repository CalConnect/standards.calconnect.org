# frozen_string_literal: true

require "fileutils"
require "json"

module Registry
  # The versioned documents-index payload (contract v1,
  # TODO.improvements/01). Immutable after build; written with a stable
  # key order so identical input produces byte-identical output.
  class Catalog
    attr_reader :meta, :items

    def initialize(meta:, items:)
      @meta = meta
      @items = items.freeze
      freeze
    end

    def to_h
      {
        "$schema" => SCHEMA_ID,
        "version" => CATALOG_VERSION,
        "generated_at" => meta[:generated_at],
        "org" => meta[:org],
        "urn_namespace" => meta[:urn_namespace],
        "url_scheme" => meta[:url_scheme],
        "generator" => meta[:generator],
        "links" => {
          "catalog" => "/catalog.json",
          "search" => "/search-index.json",
          "feed" => "/feed.xml",
          "opensearch" => "/opensearch.xml",
        },
        "items" => items.map(&:dup),
      }
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(to_h) << "\n")
      path
    end

    def self.from_file(path)
      data = JSON.parse(File.read(path))
      new(meta: {
            generated_at: data["generated_at"],
            org: data["org"],
            urn_namespace: data["urn_namespace"],
            url_scheme: data["url_scheme"],
            generator: data["generator"],
          },
          items: data["items"])
    end
  end
end
