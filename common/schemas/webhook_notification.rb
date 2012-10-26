{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "properties" => {
      "events" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "properties" => {
            "code" => {
              "type" => "string",
              "minLength" => 1,
              "ifmissing" => "error"
            },
            "params" => {
              "type" => "object"
            }
          }
        }
      }
    },

    "additionalProperties" => false,
  },
}
