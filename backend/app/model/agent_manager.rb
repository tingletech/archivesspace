module AgentManager

  @@registered_agents ||= {}


  def self.register_agent_type(agent_class, opts)
    opts[:model] = agent_class
    @@registered_agents[agent_class] = opts
  end


  def self.type_to_model_map
    Hash[self.registered_agents.map {|agent_type|
           [agent_type[:jsonmodel], agent_type[:model]]
         }]
  end


  def self.registered_agents
    @@registered_agents.values
  end


  def self.agent_type_of(agent_class)
    @@registered_agents[agent_class]
  end


  module Mixin

    def self.included(base)
      base.extend(ClassMethods)
      base.set_model_scope :global
    end


    module ClassMethods

      def register_agent_type(opts)
        AgentManager.register_agent_type(self, opts)

        self.one_to_many my_agent_type[:name_type]
        self.one_to_many :agent_contact

        self.jsonmodel_hint(:the_property => :names,
                            :contains_records_of_type => my_agent_type[:name_type],
                            :corresponding_to_association => my_agent_type[:name_type],
                            :always_resolve => true)

        self.jsonmodel_hint(:the_property => :agent_contacts,
                            :contains_records_of_type => :agent_contact,
                            :corresponding_to_association => :agent_contact,
                            :always_resolve => true)

      end


      def my_agent_type
        AgentManager.agent_type_of(self)
      end


      def sequel_to_jsonmodel(obj, type, opts = {})
        json = super
        json.agent_type = my_agent_type[:jsonmodel].to_s
        json
      end


      def agents_matching(query, max)
        self.where(my_agent_type[:name_type] => my_agent_type[:name_model].
                   where(Sequel.like(Sequel.function(:lower, :sort_name),
                                     "#{query}%".downcase))).first(max)
      end
    end
  end
end
