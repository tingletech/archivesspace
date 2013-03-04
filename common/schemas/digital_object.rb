{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "parent" => "abstract_archival_object",
    "uri" => "/repositories/:repo_id/digital_objects",
    "properties" => {

      "digital_object_id" => {"type" => "string", "ifmissing" => "error"},
      "publish" => {"type" => "boolean", "default" => true},
      "level" => {"type" => "string", "dynamic_enum" => "digital_object_level"},
      "digital_object_type" => {
        "type" => "string",
        "dynamic_enum" => "digital_object_digital_object_type"
      },

      "restrictions" => {"type" => "boolean", "default" => false},

      "notes" => {
            "type" => "array",
            "items" => {"type" => [{"type" => "JSONModel(:note_bibliography) object"},
                                   {"type" => "JSONModel(:note_digital_object) object"}]},
          },

      "linked_instances" => {
        "type" => "array",
        "readonly" => "true",
        "items" => {
          "type" => "object",
          "subtype" => "ref",
          "properties" => {
            "ref" => {
              "type" => ["JSONModel(:resource) uri", "JSONModel(:archival_object) object"],
              "ifmissing" => "error"
            },
            "_resolved" => {
              "type" => "object",
              "readonly" => "true"
            }
          }
        },
      },
    },

    "additionalProperties" => false
  },
}
