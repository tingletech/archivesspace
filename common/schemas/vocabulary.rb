{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "uri" => "/vocabularies",
    "properties" => {
      "uri" => {"type" => "string", "required" => false},
      "ref_id" => {"type" => "string", "minLength" => 1, "ifmissing" => "error"},
      "name" => {"type" => "string", "minLength" => 1, "ifmissing" => "error"},

      "terms" => {"type" => "array", "items" => {"type" => "JSONModel(:term) object"}, "readonly" => true},
    },

    "additionalProperties" => false,
  },
}
