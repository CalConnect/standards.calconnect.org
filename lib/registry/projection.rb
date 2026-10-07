# frozen_string_literal: true

module Registry
  # The Relaton record (`bibliographic`) is the single source of truth
  # (TODO.improvements/02). Every rule here derives a catalog field from
  # it (falling back to release metadata only where Relaton is silent),
  # and Registry::Consistency recomputes them to detect drift. The rules
  # are also documented in the catalog schema description.
  module Projection
    module_function

    def identifier(bib, raw)
      primary_docidentifier(bib) || raw["identifier"] || raw["id"]
    end

    def title(bib, raw)
      titles = array(bib["title"])
      main = titles.find { |t| t.is_a?(Hash) && t["type"] == "main" } || titles.first
      content = main.is_a?(Hash) ? main["content"] : main
      content = content.to_s.strip
      return content unless content.empty?

      raw["title"].to_s
    end

    def abstract(bib)
      abstracts = array(bib["abstract"])
      first = abstracts.first
      content = first.is_a?(Hash) ? first["content"] : first
      content.to_s.strip.empty? ? nil : content
    end

    def doctype(bib, raw)
      value = dig_first(bib, "ext", "doctype")
      content = value.is_a?(Hash) ? value["content"] : value
      content = content.to_s.strip
      return content unless content.empty?

      fallback = raw["doctype"].to_s.strip
      fallback.empty? ? nil : fallback
    end

    def stage(bib, raw)
      value = dig_first(bib, "status", "stage")
      content = value.is_a?(Hash) ? value["content"] : value
      content = content.to_s.strip.downcase
      return content unless content.empty?

      fallback = raw["stage"].to_s.strip.downcase
      fallback.empty? ? "published" : fallback
    end

    def stage_abbreviation(bib)
      value = bib.dig("status", "stage", "abbreviation")
      value.nil? || value.to_s.empty? ? nil : value
    end

    def date(bib, raw)
      dates = array(bib["date"])
      published = dates.find { |d| d.is_a?(Hash) && d["type"] == "published" } || dates.first
      at = published.is_a?(Hash) ? published["at"] : nil
      at ||= raw.dig("source", "releaseDate")
      at ||= raw["revdate"]
      return nil if at.nil?

      at.to_s.split(/[T ]/).first
    end

    def language(bib)
      languages = array(bib["language"]).map { |l| l.is_a?(Hash) ? l["content"] : l }.compact
      languages.empty? ? nil : languages
    end

    def license(bib, default)
      entry = array(bib["license"]).first
      entry ||= default
      return nil if entry.nil?

      entry.is_a?(Hash) ? entry.slice("name", "url", "spdx").compact : { "name" => entry.to_s }
    end

    def copyright(bib)
      array(bib["copyright"]).filter_map do |entry|
        next unless entry.is_a?(Hash)

        owner = array(entry["owner"]).filter_map do |o|
          next if o.nil?

          name = o.dig("organization", "name") || o.dig("person", "name")
          name = array(name).map { |n| n.is_a?(Hash) ? n["content"] : n }.compact.first if name
          name
        end.first

        { "from" => entry["from"], "to" => entry["to"], "owner" => owner }.compact
      end.then { |list| list.empty? ? nil : list }
    end

    def authors(bib)
      array(bib["contributor"]).filter_map do |contrib|
        person = contrib["person"]
        next if person.nil?

        name = person_name(person)
        next if name.nil?

        role = array(contrib["role"]).first
        role_type = role.is_a?(Hash) ? role["type"] : role
        { "name" => name, "role" => role_type }
      end
    end

    def committee(bib)
      array(bib["contributor"]).filter_map do |contrib|
        subdivisions = array(contrib.dig("organization", "subdivision"))
        subdivision = subdivisions.first
        next if subdivision.nil?

        names = array(subdivision["name"]).first
        names.is_a?(Hash) ? names["content"] : names
      end.first
    end

    def relaton_schema_version(bib)
      version = bib["schema_version"]
      version.to_s.empty? ? nil : version
    end

    def self.document_id(slug)
      slug.to_s.sub(/-\d{4}$/, "")
    end

    class << self
      private

      def primary_docidentifier(bib)
      identifiers = array(bib["docidentifier"])
      primary = identifiers.find { |d| d.is_a?(Hash) && d["primary"] == true } || identifiers.first
      content = primary.is_a?(Hash) ? primary["content"] : primary
      content.to_s.strip.empty? ? nil : content
    end

    def dig_first(bib, *keys)
      value = bib.dig(*keys)
      value.is_a?(Array) ? value.first : value
    end

    def person_name(person)
      names = person["name"] || {}
      complete = names["completename"]
      complete = complete["content"] if complete.is_a?(Hash)
      return complete unless complete.to_s.strip.empty?

      surname = names["surname"]
      given = names["given"]
      given = given.is_a?(Hash) ? given["content"] : given
      parts = [given, surname].compact.reject { |p| p.to_s.strip.empty? }
      parts.empty? ? nil : parts.join(" ")
    end

    def array(value)
      value.nil? ? [] : (value.is_a?(Array) ? value : [value])
    end
    end
  end
end
