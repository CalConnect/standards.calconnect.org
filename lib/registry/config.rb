# frozen_string_literal: true

require "yaml"

module Registry
  # Instance configuration for the registry data layer. An instance is an
  # organization that provides configuration, branding and content — never
  # engine code (TODO.improvements/11).
  #
  # Sources:
  #   site config (Jekyll _config.yml)   -> registry: map
  #     org, urn_namespace, url_scheme, docs_prefix, features,
  #     license_default
  #   aggregate config (metanorma.aggregate.yml)
  #     output_dir, display_categories
  class Config
    DEFAULT_URL_SCHEME = "/docs/:document_id/:year/"
    DEFAULT_DOCS_PREFIX = "/docs"

    attr_reader :org, :urn_namespace, :url_scheme, :docs_prefix, :features,
                :license_default, :display_categories, :output_dir,
                :registry_dir, :generator_label

    def initialize(site_config_path: "_config.yml", aggregate_config_path: "metanorma.aggregate.yml",
                   registry_dir: "registry", generator_label: nil)
      site = load_yaml(site_config_path)
      aggregate = load_yaml(aggregate_config_path)
      registry = (site || {})["registry"] || {}

      @org = registry["org"]
      @urn_namespace = registry["urn_namespace"] || @org
      @url_scheme = registry["url_scheme"] || DEFAULT_URL_SCHEME
      @docs_prefix = registry["docs_prefix"] || DEFAULT_DOCS_PREFIX
      @features = registry["features"] || {}
      @license_default = registry["license_default"]
      @display_categories = aggregate["display_categories"] || []
      @output_dir = aggregate["output_dir"] || "_site/docs"
      @registry_dir = registry_dir
      @generator_label = generator_label
    end

    def relaton_index_path
      File.join(output_dir, "relaton", "index.json")
    end

    def catalog_path
      File.join(registry_dir, "catalog.json")
    end

    def search_index_path
      File.join(registry_dir, "search-index.json")
    end

    def backfill_path
      File.join(registry_dir, "backfill.json")
    end

    def schema_path
      File.join("_data", "schemas", "documents.schema.json")
    end

    def feature?(name, default: true)
      value = features[name]
      value.nil? ? default : value
    end

    def display_category_for(doctype)
      return nil if doctype.nil? || doctype.to_s.empty?

      category = display_categories.find do |cat|
        (cat["doctypes"] || []).include?(doctype)
      end
      return nil unless category

      { "name" => category["name"], "slug" => category["slug"] }
    end

    private

    def load_yaml(path)
      File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
    end
  end
end
