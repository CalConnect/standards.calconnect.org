# frozen_string_literal: true

require "json"

module Registry
  # Derived search corpus (TODO.improvements/07): a separate contract,
  # fetchable at /search-index.json — never embedded in pages.
  class SearchIndex
    SEARCH_FIELDS = %i[slug document_id id title abstract doctype stage date url].freeze

    attr_reader :meta, :documents

    def initialize(meta:, documents:)
      @meta = meta
      @documents = documents
      freeze
    end

    def self.build(items, generated_at:, org:)
      documents = items.map do |item|
        {
          "slug" => item["slug"],
          "document_id" => item["document_id"],
          "id" => item["id"],
          "title" => item["title"],
          "abstract" => item["abstract"],
          "doctype" => item["doctype"],
          "stage" => item["stage"],
          "date" => item["date"],
          "url" => item["url"],
        }
      end.sort_by { |d| d["date"].to_s }.reverse
      new(meta: { generated_at: generated_at, org: org }, documents: documents)
    end

    def to_h
      {
        "$schema" => "https://schemas.metanorma.org/registry/search-index/v1.json",
        "version" => CATALOG_VERSION,
        "generated_at" => meta[:generated_at],
        "org" => meta[:org],
        "documents" => documents,
      }
    end

    def write(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(to_h) << "\n")
      path
    end
  end
end
