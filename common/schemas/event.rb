{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "type" => "object",
    "uri" => "/repositories/:repo_id/events",
    "properties" => {
      "uri" => {"type" => "string", "required" => false},

      "external_ids" => {
        "type" => "array",
        "items" => {
          "type" => "object",
          "properties" => {
            "external_id" => {"type" => "string"},
            "source" => {"type" => "string"},
          }
        }
      },

      "event_type" => {
        "type" => "string",
        "ifmissing" => "error",
        "enum" => ["accession", "accumulation", "acknowledgement", "agreement received",
                   "agreement sent", "appraisal", "assessment", "capture", "cataloging",
                   "collection", "compression", "contribution", "custody transfer", "deaccession",
                   "decompression", "decryption", "deletion", "digital signature validation",
                   "fixity check", "ingestion", "message digest calculation", "migration",
                   "normalization", "processing", "publication", "replication", "resource merge",
                   "resource component transfer", "validation", "virus check"]



      },
      "date" => {"type" => "JSONModel(:date) object", "ifmissing" => "error"},
      "outcome" => {"type" => "string"},
      "outcome_note" => {"type" => "string"},

      "suppressed" => {"type" => "boolean"},

      "linked_agents" => {
        "type" => "array",
        "ifmissing" => "error",
        "minItems" => 1,
        "items" => {
          "type" => "object",
          "subtype" => "ref",
          "properties" => {
            "role" => {
              "type" => "string",
              "enum" => ["authorizer", "executing_program", "implementer", "recipient", "transmitter", "validator"],
              "ifmissing" => "error",
            },

            "ref" => {"type" => [{"type" => "JSONModel(:agent_corporate_entity) uri"},
                                 {"type" => "JSONModel(:agent_family) uri"},
                                 {"type" => "JSONModel(:agent_person) uri"},
                                 {"type" => "JSONModel(:agent_software) uri"}],
              "ifmissing" => "error"},
            "_resolved" => {
              "type" => "object",
              "readonly" => "true"
            }
          }
        }
      },

      "linked_records" => {
        "type" => "array",
        "ifmissing" => "error",
        "minItems" => 1,
        "items" => {
          "type" => "object",
          "subtype" => "ref",
          "properties" => {
            "role" => {
              "type" => "string",
              "enum" => ["source", "outcome", "transfer"],
              "ifmissing" => "error",
            },
            "ref" => {
              "type" => [{"type" => "JSONModel(:accession) uri"},
                         {"type" => "JSONModel(:resource) uri"},
                         {"type" => "JSONModel(:archival_object) uri"}],
              "ifmissing" => "error"
            },
            "_resolved" => {
              "type" => "object",
              "readonly" => "true"
            }
          }
        }
      },
    },

    "additionalProperties" => false
  }
}
