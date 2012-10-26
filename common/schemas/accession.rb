{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "uri" => "/repositories/:repo_id/accessions",
    "properties" => {
      "uri" => {"type" => "string", "required" => false},

      "title" => {"type" => "string", "minLength" => 1, "ifmissing" => "error"},

      "id_0" => {"type" => "string", "ifmissing" => "error", "minLength" => 1, "pattern" => "^[a-zA-Z0-9]*$"},
      "id_1" => {"type" => "string", "required" => false, "default" => "", "pattern" => "^[a-zA-Z0-9]*$"},
      "id_2" => {"type" => "string", "required" => false, "default" => "", "pattern" => "^[a-zA-Z0-9]*$"},
      "id_3" => {"type" => "string", "required" => false, "default" => "", "pattern" => "^[a-zA-Z0-9]*$"},

      "content_description" => {"type" => "string", "ifmissing" => "warn"},
      "condition_description" => {"type" => "string", "ifmissing" => "warn"},

      "accession_date" => {"type" => "date", "minLength" => 1, "ifmissing" => "error"},

      "subjects" => {"type" => "array", "items" => {"type" => "JSONModel(:subject) uri_or_object"}},
      "extents" => {"type" => "array", "items" => {"type" => "JSONModel(:extent) object"}},
      "dates" => {"type" => "array", "items" => {"type" => "JSONModel(:date) object"}},
      "external_documents" => {"type" => "array", "items" => {"type" => "JSONModel(:external_document) object"}},
      "rights_statements" => {"type" => "array", "items" => {"type" => "JSONModel(:rights_statement) object"}},
      "deaccessions" => {"type" => "array", "items" => {"type" => "JSONModel(:deaccession) object"}},
    },

    "additionalProperties" => false,
  },
}
