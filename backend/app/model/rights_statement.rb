require_relative 'auto_generator'
require 'securerandom'

class RightsStatement < Sequel::Model(:rights_statement)
  include ASModel
  include ExternalDocuments
  include AutoGenerator

  set_model_scope :repository
  corresponds_to JSONModel(:rights_statement)

  auto_generate :property => :identifier,
                :generator => proc  { |json|
                  SecureRandom.hex
                },
                :only_on_create => true

end
