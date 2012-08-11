{
  :schema => {
    "type" => "object",
    "uri" => "/repositories/:repo_id/archival_objects",
    "properties" => {
      "uri" => {"type" => "string", "required" => false},
      "ref_id" => {"type" => "string", "ifmissing" => "error", "minLength" => 1, "pattern" => "^[a-zA-Z0-9]*$"},
      "component_id" => {"type" => "string", "required" => false, "default" => "", "pattern" => "^[a-zA-Z0-9]*$"},
      "title" => {"type" => "string", "minLength" => 1, "required" => true},
      "level" => {"type" => "string", "minLength" => 1, "required" => false},
      "parent" => {"type" => "string", "required" => false, "pattern" => "/repositories/[0-9]+/archival_objects/[0-9]+$"},
      "collection" => {"type" => "string", "required" => false, "pattern" => "/repositories/[0-9]+/collections/[0-9]+$"},

      "subjects" => {"type" => "array", "items" => { "type" => "string", "pattern" => "/subjects/[0-9]+$" } },
    },

    "additionalProperties" => false,
  },
}
