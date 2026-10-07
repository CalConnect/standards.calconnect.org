# frozen_string_literal: true

module Registry
  # Canonical URL construction from data alone (TODO.improvements/03).
  # The scheme is an engine default from instance config with tokens
  # :document_id, :year, :edition. The index alone is sufficient to
  # reconstruct every URL these rules produce.
  module Urls
    module_function

    # Deterministic ordering key for editions of one document.
    def edition_sort_key(item)
      edition = item["edition"].to_s
      numeric = edition.match?(/\A\d+(\.\d+)*\z/) ? edition.split(".").map(&:to_i) : [0]
      [item["date"].to_s, numeric, item["slug"].to_s]
    end

    # Latest edition of a group (items sharing document_id).
    def latest(items)
      items.max_by { |item| edition_sort_key(item) }
    end

    # Versioned segment for one item within its document group. The base
    # segment is the publication year; when several editions share the
    # same year the edition number disambiguates ("/2010-ed1.1").
    def version_segment(item, group)
      base = item["year"].to_s
      base = item["edition"].to_s if base.empty?
      same_base = group.reject { |i| i.equal?(item) }
                       .select { |i| segment_base(i) == base }
      return base if same_base.empty?

      suffix = item["edition"].to_s
      suffix = item["slug"] if suffix.empty?
      "#{base}-ed#{suffix}"
    end

    def landing_path(item, group, url_scheme)
      path = url_scheme.dup
      path.sub!(":document_id", item["document_id"])
      path.sub!(":year", version_segment(item, group))
      path.sub!(":edition", item["edition"].to_s)
      path = "/#{path}" unless path.start_with?("/")
      path
    end

    def latest_path(item)
      "/docs/#{item['document_id']}/"
    end

    def file_url(path, docs_prefix)
      "#{docs_prefix}/#{path}"
    end

    class << self
      private

      def segment_base(item)
        item["year"].to_s.empty? ? item["edition"].to_s : item["year"]
      end
    end
  end
end
