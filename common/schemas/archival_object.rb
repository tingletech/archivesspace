{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "parent" => "abstract_archival_object",
    "uri" => "/repositories/:repo_id/archival_objects",
    "properties" => {
      "ref_id" => {"type" => "string", "pattern" => "^[a-zA-Z0-9]*$"},
      "component_id" => {"type" => "string", "required" => false, "default" => ""},

      "level" => {"type" => "string", "ifmissing" => "error", "enum" => ["class", "collection", "file", "fonds", "item", "otherlevel", "recordgrp", "series", "subfonds", "subgrp", "subseries"]},
      "other_level" => {"type" => "string"},

      "title" => {"ifmissing" => nil},
      "title_auto_generate" => {"type" => "boolean", "default" => false},

      "parent" => {
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {"type" => "JSONModel(:archival_object) uri"},
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          }
        }
      },

      "resource" => {
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {"type" => "JSONModel(:resource) uri"},
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          }
        }
      },

      "position" => {"type" => "integer", "required" => false},

      "instances" => {"type" => "array", "items" => {"type" => "JSONModel(:instance) object"}},

      "notes" => {
        "type" => "array",
        "items" => {"type" => [{"type" => "JSONModel(:note_bibliography) object"},
                               {"type" => "JSONModel(:note_index) object"},
                               {"type" => "JSONModel(:note_multipart) object"},
                               {"type" => "JSONModel(:note_singlepart) object"}]},
      },
    },



    "additionalProperties" => false,
  },
}
