module CalConnect
  module Build
    class DocTypeRegistry
      Entry = Struct.new(:key, :title, keyword_init: true)

      TYPES = [
        Entry.new(key: "standard", title: "CalConnect Standards"),
        Entry.new(key: "public-review", title: "Public Review Documents"),
        Entry.new(key: "pending-publication", title: "Pending Publication"),
        Entry.new(key: "report", title: "CalConnect Reports"),
        Entry.new(key: "specification", title: "CalConnect Specifications"),
        Entry.new(key: "administrative", title: "Administrative Documents"),
        Entry.new(key: "directive", title: "CalConnect Directives"),
        Entry.new(key: "advisory", title: "CalConnect Advisories"),
        Entry.new(key: "amendment", title: "Amendments"),
        Entry.new(key: "technical-corrigendum", title: "Technical Corrigenda"),
        Entry.new(key: "guide", title: "CalConnect Guides")
      ].freeze

      def keys = TYPES.map(&:key)

      def title_for(key)
        entry = TYPES.find { |t| t.key == key }
        entry&.title || "#{key.capitalize} Documents"
      end

      def each(&block) = TYPES.each(&block)
    end
  end
end
