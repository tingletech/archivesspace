require 'psych'

module ASpaceImport
  module Crosswalk
    
    # Module methods and helpers  
      
    def self.init(opts)

      @models = {}
      @link_conditions = []
      
      @walk = Psych.load(IO.read(File.join(File.dirname(__FILE__),
                                                "../crosswalks",
                                                "#{opts[:crosswalk]}.yml")))
      
      entries.each do |key, xdef|
        record_type = xdef.has_key?('record_type') ? xdef['record_type'] : key
        @models[key] = create_model(key, JSONModel::JSONModel(record_type))
      end                                                                               
    end 
    
    def self.entries
      @walk['entities']
    end
    
    def self.models
      @models
    end
    
    def self.add_link_condition(lamb)
      @link_conditions << lamb
    end
    
    def self.link_conditions
      @link_conditions
    end
    
    def self.mint_id
      @counter ||= 1000
      @counter += 1
    end
      
    
    def self.create_model(model_key, json_model)
  
      cls = Class.new(json_model) do
        
        def self.init(model_key)
          @model_key = model_key
          @dispatcher_class = Class.new(ASpaceImport::Crosswalk::PropertyReceiverDispatcher)
          @dispatcher_class.init(self)
        end
        
        def self.model_key
          @model_key
        end
        
        
        def initialize(*args)
          
          super
          
          @dispatcher = self.class.instance_variable_get(:@dispatcher_class).new(self)
          
          # Set a pre-save URI to be dereferenced by the backend
          if self.class.method_defined? :uri
            self.uri = self.class.uri_for(ASpaceImport::Crosswalk.mint_id) 
          end
          
        end
        
        def receivers
          @dispatcher
        end
                 
        def set_default_properties
          self.receivers.each { |r| r.receive }
        end
        
        def block_further_reception
          @done_being_received = true
        end

        def done_being_received?
          @done_being_received ||= false
          @done_being_received
        end
      end
            
      cls.init(model_key)
      
      cls
    end  
      

    # Intermediate / chaining class for yielding property receivers given
    # either an xpath or a record_type along with an optional depth (of
    # the parsing context into which the reciever will be yielded)

    class PropertyReceiverDispatcher
      
      def self.init(model)
        @receiver_classes = ASpaceImport::Crosswalk.property_receivers(model)
      end
      
      def self.receiver_classes
        @receiver_classes
      end
      
      def initialize(json)
        @json = json
        @receivers = {}
        # ASpaceImport::Crosswalk.property_receivers(@json.class).each do |p, r|
        self.class.receiver_classes.each do |p, r|
          @receivers[p] = r.new(@json)
        end 
      end
      
      def each
        @receivers.each { |p, r| yield r }                  
      end


      def by_name(prop_name)
        @receivers[prop_name]
      end


      def for_obj(json)
        return nil if json.done_being_received?
        
        @receivers.each do |p, r|
          yield r unless ASpaceImport::Crosswalk.link_conditions.map {|lc| lc.call(r, json) }.include?(false)          
        end
      end

    end

    # Generate receiver classes for each property of a 
    # json model

    def self.property_receivers(model)
      receivers = {}

      self.entries[model.model_key]['properties'].each do |p, defn|
         receivers[p] = self.initialize_receiver(p, model.schema['properties'][p], defn)
      end
     
      receivers
    end

    # @param property_name - [String] the name of the property
    # @param def_from_schema - [Hash] the schema fragement that defines the property
    # @param def_from_xwalk - [Hash] the crosswalk fragment that maps source data to 
    #  the property
    
    def self.initialize_receiver(property_name, def_from_schema, def_from_xwalk)

      if def_from_schema.nil?
        raise CrosswalkException.new(:property => property_name, :property_def => nil)
      end

      Class.new(PropertyReceiver) do
        
        class << self
          attr_reader :property
          attr_reader :property_type
          attr_reader :xdef
          attr_reader :valid_json_types
        end
        
        @property = property_name
        @property_type, @valid_json_types = ASpaceImport::Crosswalk.get_property_type(def_from_schema)
        @xdef = def_from_xwalk
        
        if @property_type.match /^record/ 
          if @valid_json_types.empty?
            raise CrosswalkException.new(:property => @property, :val_type => @property_type) 
          end
        end
      end
    end
    
    class CrosswalkException < StandardError
      attr_accessor :property
      attr_accessor :val_type
      attr_accessor :property_def

      def initialize(opts)
        @property = opts[:property]
        @val_type = opts[:val_type]
        @property_def = opts[:property_def]
      end

      def to_s
        if @property_def
          "#<:CrosswalkException: Can't classify the property schema: #{property_def.inspect}>"
        elsif @val_type
          "#<:CrosswalkException: Can't identify a Model for property '#{property}' of type '#{val_type}'>"
        else
          "#<:CrosswalkException: Can't identify a schema fragment for property '#{property}'>"
        end
      end
    end
    
    
    # Objects to manage the setting of a property of the
    # master json object (@object)  
    
    class PropertyReceiver
      attr_reader :object
      attr_accessor :cache
      
      def initialize(json)
        @object = json
        @cache = {}
      end
      
      def to_s
        "Property Receiver for #{@object.class.record_type}\##{self.class.property}"
      end
      
      # Run defined procedures, apply defaults, and clean up
      # whitespace padding for a parsed value.
      
      def pre_process(val)
        if self.class.xdef['procedure'] && val
          proc = eval "lambda { #{self.class.xdef['procedure']} }"
          val = proc.call(val)
        end
        
        if val == nil and self.class.xdef['default'] && !@object.send("#{self.class.property}")
          val = self.class.xdef['default']
        end
        
        if val.is_a? String
           val.gsub!(/^[\s\t\n]*/, '')
           val.gsub!(/[\s\t\n]*$/, '')
           val = nil if val.empty?
        end
        
        val
      end
      
      def <<(val)
        receive(val)
      end
      
      # @param val - string, hash, or JSON object
      
      def receive(val = nil)
        
        val = pre_process(val)
                
        return false if val == nil
        
        case self.class.property_type

        when /^record_uri_or_record_inline/
          val.block_further_reception if val.respond_to? :block_further_reception
          if val.class.method_defined? :uri
            val = val.uri
          elsif val.class.method_defined? :to_hash
            val = val.to_hash
          end
                  
        when /^record_uri/
          val = val.uri
          
        when /^record_inline/
          val.block_further_reception if val.respond_to? :block_further_reception
          val = val.to_hash
        
        when /^record_ref/
          if val.class.method_defined? :uri
            val = {'ref' => val.uri}
          end  
        end
        
        if self.class.property_type.match /list$/       
          val = @object.send("#{self.class.property}").push(val)
        end
        
        @object.send("#{self.class.property}=", val)
      end
    end


    # Helpers that should probably be relocated:

    def self.ref_type_list(property_ref_type)
      if property_ref_type.is_a? Array
        property_ref_type.map { |t| t['type'].scan(/:([a-zA-Z_]*)/)[0][0] }
      else  
        property_ref_type.scan(/:([a-zA-Z_]*)/)[0][0]
      end
    end
    
    # @param property_def - property fragment from a json schema
    # @returns - [property_type_code, array_of_qualified_json_types]
    
    def self.get_property_type(property_def)

      # subrecord slots taking more than one type

      if property_def['type'].is_a? Array
        if property_def['type'].reject {|t| t['type'].match(/object$/)}.length != 0
          raise CrosswalkException.new(:property_def => property_def)
        end
        
        return [:record_inline, property_def['type'].map {|t| t['type'].scan(/:([a-zA-Z_]*)/)[0][0] }]
      end

      # all other cases

      case property_def['type']

      when 'boolean'
        [:boolean, nil]
      
      when 'date'
        [:string, nil]
        
      when 'string'
        [:string, nil]
        
      when 'object'
        if property_def['subtype'] == 'ref'          
          [:record_ref, ref_type_list(property_def['properties']['ref']['type'])]
        else
          raise CrosswalkException.new(:property_def => property_def)
        end
        
      when 'array'
        arr = get_property_type(property_def['items'])
        [(arr[0].to_s + '_list').to_sym, arr[1]]
        
      when /^JSONModel\(:([a-z_]*)\)\s(uri)$/
        [:record_uri, [$1]]
        
      when /^JSONModel\(:([a-z_]*)\)\s(uri_or_object)$/
        [:record_uri_or_record_inline, [$1]]
        
      when /^JSONModel\(:([a-z_]*)\)\sobject$/
        [:record_inline, [$1]]
  
      else
        
        raise CrosswalkException.new(:property_def => property_def)
      end
    end
    
    # @param json - JSON Object to be modified
    # @param ref_source - a hash mapping old uris to new uris
    # The ref_source values are evaluated by a block
    
    def self.update_record_references(json, ref_source)
      data = json.to_hash
      data.each do |k, v|

        property_type = get_property_type(json.class.schema["properties"][k])[0]

        if property_type == :record_ref && ref_source.has_key?(v['ref'])
          data[k]['ref'] = yield ref_source[v['ref']]
          
        elsif property_type == :record_ref_list

          v.each {|li| li['ref'] = yield ref_source[li['ref']] if ref_source.has_key?(li['ref'])}
                 
        elsif property_type.match(/^record_uri(_or_record_inline)?$/) \
          and v.is_a? String \
          and !v.match(/\/vocabularies\/[0-9]+$/) \
          and ref_source.has_key?(v)

          data[k] = yield ref_source[v]
          
        elsif property_type.match(/^record_uri(_or_record_inline)?_list$/) && v[0].is_a?(String)
          data[k] = v.map { |vn| (vn.is_a? String && vn.match(/\/.*[0-9]$/)) && ref_source.has_key?(vn) ? (yield ref_source[vn]) : vn }
        end    
      end
      
      json.set_data(data)
    end
  end
end
