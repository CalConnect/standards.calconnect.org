# frozen_string_literal: true

# Registry: the SDO-agnostic data layer for a standards registry site.
#
# Pipeline position (TODO.improvements/00-overview):
#   producer (metanorma-release aggregate, or any conforming generator)
#     -> producer outputs: <output_dir>/**, <output_dir>/relaton/index.json
#   Registry::Enricher   -> registry/catalog.json, registry/search-index.json,
#                           registry/backfill.json (the renderer-neutral handoff)
#   renderer (Jekyll reference renderer, or any conforming frontend)
#     <- reads registry/ and nothing else
#
# This library contains no instance-specific constants: organization
# identity, URN namespace, URL scheme, categories and feature flags all
# arrive through Registry::Config. It is structured to be extracted to a
# metanorma-org home verbatim (TODO.improvements/upstream/).
module Registry
  autoload :Config, "registry/config"
  autoload :MediaTypes, "registry/media_types"
  autoload :Projection, "registry/projection"
  autoload :Urls, "registry/urls"
  autoload :Catalog, "registry/catalog"
  autoload :SearchIndex, "registry/search_index"
  autoload :Backfill, "registry/backfill"
  autoload :Enricher, "registry/enricher"
  autoload :Consistency, "registry/consistency"
  autoload :Conformance, "registry/conformance"

  SCHEMA_ID = "https://schemas.metanorma.org/registry/documents-index/v1.json"
  CATALOG_VERSION = 1
end
