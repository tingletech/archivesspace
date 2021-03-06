{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "properties" => {

      "type_1" => {"type" => "string", "ifmissing" => "error", "dynamic_enum" => "container_type"},
      "indicator_1" => {"type" => "string", "minLength" => 1, "ifmissing" => "error"},
      "barcode_1" => {"type" => "string", "minLength" => 1},

      "type_2" => {"type" => "string", "dynamic_enum" => "container_type"},
      "indicator_2" => {"type" => "string"},

      "type_3" => {"type" => "string", "dynamic_enum" => "container_type"},
      "indicator_3" => {"type" => "string"},

      "container_locations" => {
        "type" => "array",
        "items" => {
          "type" => "JSONModel(:container_location) object",
        }
      }
    },

    "additionalProperties" => false,
  },
}
