{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "uri" => "/repositories/:repo_id/archival_objects",
    "properties" => {
      "uri" => {"type" => "string", "required" => false},
      "ref_id" => {"type" => "string", "ifmissing" => "error", "minLength" => 1, "pattern" => "^[a-zA-Z0-9]*$"},
      "component_id" => {"type" => "string", "required" => false, "default" => "", "pattern" => "^[a-zA-Z0-9]*$"},
      "title" => {"type" => "string", "minLength" => 1, "required" => true},

      "level" => {"type" => "string", "minLength" => 1, "required" => false},
      "parent" => {"type" => "JSONModel(:archival_object) uri", "required" => false},
      "resource" => {"type" => "JSONModel(:resource) uri", "required" => false},

      "subjects" => {"type" => "array", "items" => {"type" => "JSONModel(:subject) uri_or_object"}},
      "extents" => {"type" => "array", "items" => {"type" => "JSONModel(:extent) object"}},
      "dates" => {"type" => "array", "items" => {"type" => "JSONModel(:date) object"}},
      "external_documents" => {"type" => "array", "items" => {"type" => "JSONModel(:external_document) object"}},
      "rights_statements" => {"type" => "array", "items" => {"type" => "JSONModel(:rights_statement) object"}},
      "instances" => {"type" => "array", "items" => {"type" => "JSONModel(:instance) object"}},
    },

    "additionalProperties" => false,
  },
}
