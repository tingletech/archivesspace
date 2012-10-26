{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "parent" => "abstract_agent",
    "uri" => "/agents/families",
    "properties" => {
      "names" => {
        "type" => "array",
        "items" => {"type" => "JSONModel(:name_family) uri_or_object"},
        "ifmissing" => "error",
        "minItems" => 1
      },
    },
  },
}
