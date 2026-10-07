# frozen_string_literal: true

module Registry
  # Format -> IANA media type mapping for known artifact formats. Unknown
  # formats fall back to application/octet-stream (TODO.improvements/05).
  module MediaTypes
    FORMAT_MEDIA_TYPES = {
      "html" => "text/html",
      "pdf" => "application/pdf",
      "xml" => "application/xml",
      "rxl" => "application/xml",
      "doc" => "application/msword",
      "docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "odt" => "application/vnd.oasis.opendocument.text",
      "epub" => "application/epub+zip",
      "json" => "application/json",
      "txt" => "text/plain",
      "adoc" => "text/plain",
      "csv" => "text/csv",
      "png" => "image/png",
      "jpg" => "image/jpeg",
      "jpeg" => "image/jpeg",
      "svg" => "image/svg+xml",
      "zip" => "application/zip",
    }.freeze

    DEFAULT = "application/octet-stream"

    def self.for(format)
      FORMAT_MEDIA_TYPES.fetch(format.to_s.downcase, DEFAULT)
    end
  end
end
