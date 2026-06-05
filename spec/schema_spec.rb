require "json"
require "json_schemer"

RSpec.describe "Document index schema" do
  let(:schema_path) { File.expand_path("../_data/schemas/documents.schema.json", __dir__) }
  let(:schema) { JSON.parse(File.read(schema_path)) }
  let(:doc_schema) { schema["$defs"]["document"] }
  let(:schemer) { JSONSchemer.schema(doc_schema) }

  let(:data_path) { File.expand_path("../_data/documents.json", __dir__) }
  let(:data) do
    skip("documents.json not found — run `rake fetch`") unless File.exist?(data_path)
    JSON.parse(File.read(data_path))
  end

  it "has a valid schema document" do
    expect(schema["title"]).to eq("CalConnect Documents Index")
    expect(schema["$defs"]["document"]).to be_a(Hash)
  end

  it "contains an items array" do
    expect(data).to have_key("items")
    expect(data["items"]).to be_an(Array)
  end

  it "every document satisfies the document subschema" do
    violations = []
    data["items"].each_with_index do |doc, i|
      schemer.validate(doc).each do |error|
        violations << "##{i} (#{doc['id']}): #{error['error']}"
      end
    end
    expect(violations).to be_empty, -> { "Schema violations:\n  #{violations.first(10).join("\n  ")}" }
  end

  describe "each document" do
    it "has a non-empty id" do
      data["items"].each do |doc|
        expect(doc["id"]).to be_a(String), -> { "Expected string id, got #{doc['id'].inspect}" }
        expect(doc["id"]).not_to be_empty
      end
    end

    it "has a recognized doctype (when present)" do
      valid_doctypes = schema["$defs"]["document"]["properties"]["doctype"]["enum"]
      data["items"].each do |doc|
        next if doc["doctype"].nil? || doc["doctype"].empty?
        expect(valid_doctypes).to include(doc["doctype"]), -> {
          "#{doc['id']}: unrecognized doctype '#{doc['doctype']}'"
        }
      end
    end

    it "has a doctype_class derived from doctype" do
      data["items"].each do |doc|
        next if doc["doctype"].nil? || doc["doctype"].empty?
        expect(doc["doctype_class"]).to start_with("type-"), -> {
          "#{doc['id']}: doctype_class '#{doc['doctype_class']}' doesn't follow type- prefix convention"
        }
      end
    end

    it "has boolean or nil download flags" do
      %w[has_html has_pdf has_xml has_rxl].each do |flag|
        data["items"].each do |doc|
          expect([true, false, nil]).to include(doc[flag]), -> {
            "#{doc['id']}: #{flag} should be boolean or nil, got #{doc[flag].inspect}"
          }
        end
      end
    end
  end
end
