# frozen_string_literal: true

require "json"

module Registry
  # Tracks what the catalog honestly lacks (TODO.improvements/06 and the
  # brief's "never fabricate data" rule): fields that stay null because
  # no source provides them are listed here for backfill, alongside
  # known data-quality issues that need maintainer or source-repo action.
  class Backfill
    attr_reader :gaps

    def initialize
      @gaps = Hash.new { |h, k| h[k] = [] }
    end

    def add(kind, slug, detail = nil)
      @gaps[kind] << { "slug" => slug, "detail" => detail }.compact
    end

    def empty?
      @gaps.empty?
    end

    def to_h
      {
        "generated_at" => @generated_at,
        "notes" => [
          "Fields are null here because no source provides them — they are",
          "never invented. Backfill happens in source repositories or via",
          "instance config (license_default), not in this file by hand.",
        ],
        "gaps" => @gaps.sort.to_h,
      }
    end

    def write(path, generated_at:)
      @generated_at = generated_at
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(to_h) << "\n")
      path
    end
  end
end
