#!/usr/bin/env ruby

require 'yaml'
require 'relaton_calconnect'

ARGV.each do |file|
  hash = YAML.load_file file
  hash['root']['items'].map! do |item|
    docidtype = item['docidentifier'].match(/\w+/).to_s
    abstract = RelatonBib::FormattedString.new(content: item['abstract']) if item['abstract']
    RelatonCalconnect::CcBibliographicItem.new(
      docid: [RelatonBib::DocumentIdentifier.new(id: item['docidentifier'], type: docidtype)],
      doctype: item['doctype'],
      title: [RelatonIsoBib::HashConverter.split_title(item['title'])],
      status: RelatonBib::DocumentStatus.new(stage: item['stage']),
      link: [RelatonBib::TypedUri.new(type: 'pdf', content: item['pdf'])],
      version: RelatonBib::BibliographicItem::Version.new(item['revdate']),
      editorialgroup: RelatonIsoBib::EditorialGroup.new(technical_committee: [{ name: item['technical_committee'] }]),
      abstract: [abstract]
    ).to_hash
  end
  ext = File.extname(file)
  new_file = File.join File.dirname(file), "#{File.basename(file, ext)}_new.#{ext}"
  File.write new_file, hash.to_yaml
end
