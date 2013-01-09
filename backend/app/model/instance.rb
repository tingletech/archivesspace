class Instance < Sequel::Model(:instance)
  include ASModel

  set_model_scope :global
  corresponds_to JSONModel(:instance)

  one_to_many :container

  def_nested_record(:the_property => :container,
                    :is_array => false,
                    :contains_records_of_type => :container,
                    :corresponding_to_association => :container,
                    :always_resolve => true)

end
