require 'json-schema'
require_relative 'json_schema_utils'
require_relative 'asutils'


module JSONModel

  @@models = {}
  @@custom_validations = {}
  @@protected_fields = []
  @@strict_mode = false


  def self.custom_validations
    @@custom_validations
  end

  def strict_mode(val)
    @@strict_mode = val
  end


  class ValidationException < StandardError
    attr_accessor :invalid_object
    attr_accessor :errors
    attr_accessor :warnings

    def initialize(opts)
      @invalid_object = opts[:invalid_object]
      @errors = opts[:errors]
      @warnings = opts[:warnings]
    end

    def to_s
      "#<:ValidationException: #{{:errors => @errors, :warnings => @warnings}.inspect}>"
    end
  end


  def self.JSONModel(source)
    # Checks if a model exists first; returns the model class
    # if it exists; returns false if it doesn't exist.
    if !@@models.has_key?(source.to_s)
      load_schema(source.to_s)
    end

    @@models[source.to_s] || false
  end


  def JSONModel(source)
    JSONModel.JSONModel(source)
  end


  # Yield all known JSONModel classes
  def models
    @@models
  end


  def self.repository_for(reference)
    if reference =~ /^(\/repositories\/[0-9]+)\//
      return $1
    else
      return nil
    end
  end


  # Parse a URI reference like /repositories/123/archival_objects/500 into
  # {:id => 500, :type => :archival_object}
  def self.parse_reference(reference, opts = {})
    @@models.each do |type, model|
      id = model.id_for(reference, opts, true)
      if id
        return {:id => id, :type => type, :repository => repository_for(reference)}
      end
    end

    nil
  end


  def self.destroy_model(type)
    @@models.delete(type.to_s)
  end


  def self.schema_src(schema_name)
    # Look on the filesystem first
    schema = File.join(File.dirname(__FILE__),
                       "schemas",
                       "#{schema_name}.rb")

    if File.exists?(schema)
      return File.open(schema).read
    else
      nil
    end
  end


  def self.allow_unmapped_enum_value(val, magic_value = 'other_unmapped')
    if val.is_a? Array
      val.each { |elt| allow_unmapped_enum_value(elt) }
    elsif val.is_a? Hash
      val.each do |k, v|
        if k == 'enum'
          v << magic_value
         else
          allow_unmapped_enum_value(v)
        end
      end
    end
  end


  def self.load_schema(schema_name)
    if not @@models[schema_name]

      old_verbose = $VERBOSE
      $VERBOSE = nil
      src = schema_src(schema_name)

      return if !src

      entry = eval(src)
      $VERBOSE = old_verbose

      parent = entry[:schema]["parent"]
      if parent
        load_schema(parent)

        base = @@models[parent].schema["properties"].clone
        properties = self.deep_merge(base, entry[:schema]["properties"])

        entry[:schema]["properties"] = properties
      end

      # All records have a lock_version property that we use for optimistic concurrency control.
      entry[:schema]["properties"]["lock_version"] = {"type" => ["integer", "string"], "required" => false}

      # All records must indicate their model type
      entry[:schema]["properties"]["jsonmodel_type"] = {"type" => "string", "ifmissing" => "error"}

      if @@init_args[:allow_other_unmapped]
        allow_unmapped_enum_value(entry[:schema]['properties'])
      end

      self.create_model_for(schema_name, entry[:schema])
    end
  end


  def self.init(opts = {})

    @@init_args ||= nil

    # Skip initialisation if this model has already been loaded.
    if @@init_args
      return true
    end

    if opts.has_key?(:strict_mode)
      @@strict_mode = true
    end

    @@init_args = opts

    # Load all JSON schemas from the schemas subdirectory
    # Create a model class for each one.
    Dir.glob(File.join(File.dirname(__FILE__),
                       "schemas",
                       "*.rb")).sort.each do |schema|
      schema_name = File.basename(schema, ".rb")
      load_schema(schema_name)
    end

    require_relative "validations"

    true
  end


  def self.parse_jsonmodel_ref(ref)
    if ref.is_a? String and ref =~ /JSONModel\(:([a-zA-Z_\-]+)\) (.*)/
      [$1.intern, $2]
    else
      nil
    end
  end

  # Recursively overlays hash2 onto hash 1 
  def self.deep_merge(hash1, hash2)
    target = hash1.dup 
    hash2.keys.each do |key|
      if hash2[key].is_a? Hash and hash1[key].is_a? Hash
        target[key] = self.deep_merge(target[key], hash2[key])
        next
      end
      target[key] = hash2[key]
    end
    target
  end

  protected

  # Create and return a new JSONModel class called 'type', based on the
  # JSONSchema 'schema'
  def self.create_model_for(type, schema)

    cls = Class.new do

      # Class instance variables store the bits specific to this model
      def self.init(type, schema)
        @record_type = type
        @schema = schema
      end


      # If this class is subclassed, we won't be able to see our class instance
      # variables unless we explicitly look up the inheritance chain.
      def self.find_ancestor_class_instance(variable)
        self.ancestors.each do |clz|
          val = clz.instance_variable_get(variable)
          return val if val
        end

        nil
      end


      # Return the JSON schema that defines this JSONModel class
      def self.schema
        find_ancestor_class_instance(:@schema)
      end


      # Return the type of this JSONModel class (a keyword like
      # :archival_object)
      def self.record_type
        find_ancestor_class_instance(:@record_type)
      end


      # Define accessors for all variable names listed in 'attributes'
      def self.define_accessors(attributes)
        attributes.each do |attribute|

          if not method_defined? "#{attribute}"
            if self.schema["properties"].has_key?(attribute) && self.schema["properties"][attribute]["type"] === "array"
              define_method "#{attribute}" do
                return [] if @data[attribute].nil?
                @data[attribute]
              end
            else
              define_method "#{attribute}" do
                @data[attribute]
              end
            end
          end


          if not method_defined? "#{attribute}="
            define_method "#{attribute}=" do |value|
              @validated = false
              @data[attribute] = value
            end
          end
        end
      end


      def self.to_s
        "JSONModel(:#{self.record_type})"
      end


      # Add a custom validation to this model type.
      #
      # The validation is a block that takes a hash of properties and returns an array of pairs like:
      # [["propertyname", "the problem with it"], ...]
      def self.add_validation(name, &block)
        raise "Validation name already taken: #{name}" if @@custom_validations[name]

        @@custom_validations[name] = block

        self.schema["validations"] ||= []
        self.schema["validations"] << name
      end


      # Create an instance of this JSONModel from the data contained in 'hash'.
      def self.from_hash(hash, raise_errors = true)
        hash["jsonmodel_type"] = self.record_type.to_s

        validate(hash, raise_errors)

        # Note that I don't use the cleaned version here.  We want to keep
        # around the original extra stuff (and provide accessors for them
        # too), but just want to strip them out when converting back to JSON
        self.new(hash)
      end


      # Create an instance of this JSONModel from a JSON string.
      def self.from_json(s, raise_errors = true)
        self.from_hash(JSON.parse(s, :max_nesting => false), raise_errors)
      end


      def self.uri_and_remaining_options_for(id = nil, opts = {})
        # Some schemas (like name schemas) don't have a URI because they don't
        # need endpoints.  That's fine.
        if not self.schema['uri']
          return nil
        end

        uri = self.schema['uri']

        if not id.nil?
          uri += "/#{id}"
        end

        self.substitute_parameters(uri, opts)
      end


      # Given a numeric internal ID and additional options produce a pair containing a URI reference.
      # For example:
      #
      #     JSONModel(:archival_object).uri_for(500, :repo_id => 123)
      #
      #  might yield "/repositories/123/archival_objects/500"
      #
      def self.uri_for(id = nil, opts = {})
        result = self.uri_and_remaining_options_for(id, opts)

        result ? result[0] : nil
      end


      # The inverse of uri_for:
      #
      #     JSONModel(:archival_object).id_for("/repositories/123/archival_objects/500", :repo_id => 123)
      #
      #  might yield 500
      #
      def self.id_for(uri, opts = {}, noerror = false)
        if not self.schema['uri']
          if noerror
            return nil
          else
            raise "Missing a URI definition for class #{self.class}"
          end
        end

        pattern = self.schema['uri']
        pattern = pattern.gsub(/\/:[a-zA-Z_]+\//, '/[^/ ]+/')

        if uri =~ /#{pattern}\/([0-9]+)$/
          return $1.to_i
        else
          if noerror
            nil
          else
            raise "Couldn't make an ID out of URI: #{uri}"
          end
        end
      end


      # Return the type of the schema property defined by 'path'
      #
      # For example, type_of("names/items/type") might return a JSONModel class
      def self.type_of(path)
        type = JSONSchemaUtils.schema_path_lookup(self.schema, path)["type"]

        ref = JSONModel.parse_jsonmodel_ref(type)

        if ref
          JSONModel.JSONModel(ref.first)
        else
          Kernel.const_get(type.capitalize)
        end
      end


      def set_data(data)
        hash = ASUtils.keys_as_strings(data)
        hash["jsonmodel_type"] = self.class.record_type.to_s
        hash = self.class.apply_schema_defaults(hash)

        @data = hash
      end

      def initialize(params = {}, warnings = [])
        set_data(params)
        @warnings = warnings

        # a hash to store transient instance data
        @instance_data = {}

        self.class.define_accessors(@data.keys)
      end


      def instance_data
        @instance_data
      end


      def [](key)
        @data[key.to_s]
      end


      def []=(key, val)
        @validated = false
        @data[key.to_s] = val
      end


      # Validate the current JSONModel instance and return a list of exceptions
      # produced.
      def _exceptions
        return @validated if @validated

        exceptions = {}
        if not @always_valid
          exceptions = self.class.validate(@data, false).reject{|k, v| v.empty?}
        end

        if @errors
          exceptions[:errors] = (exceptions[:errors] or {}).merge(@errors)
        end

        @validated = exceptions
        exceptions
      end


      def add_error(attribute, message)
        # reset validation
        @validated = nil

        super
      end


      def _warnings
        exceptions = self._exceptions

        if exceptions.has_key?(:warnings)
          exceptions[:warnings]
        else
          []
        end
      end


      # Set this object instance to always pass validation.  Used so the
      # frontend can create intentionally incomplete objects that will be filled
      # out by the user.
      def _always_valid!
        @always_valid = true
        self
      end


      # Update the values of the current JSONModel instance with the contents of
      # 'params', validating before accepting the update.
      def update(params)
        @validated = false
        replace(@data.merge(params))
      end


      # Replace the values of the current JSONModel instance with the contents
      # of 'params', validating before accepting the replacement.
      def replace(params)
        @validated = false
        @@protected_fields.each do |field|
          params[field] = @data[field]
        end

        set_data(params)
      end


      def reset_from(another_jsonmodel)
        @data = another_jsonmodel.instance_eval { @data }
      end


      def to_s
        "#<JSONModel(:#{self.class.record_type}) #{@data.inspect}>"
      end

      def inspect
        self.to_s
      end


      # Produce a (possibly nested) hash from the values of this JSONModel.  Any
      # values that don't appear in the JSON schema will not appear in the
      # result.
      def to_hash(raw = false)
        return @data if raw

        @validated = false

        cleaned = self.class.drop_unknown_properties(@data)
        self.class.validate(cleaned)

        cleaned
      end


      # Produce a JSON string from the values of this JSONModel.  Any values
      # that don't appear in the JSON schema will not appear in the result.
      def to_json(opts = {})
        self.to_hash.to_json(opts.merge(:max_nesting => false))
      end


      # Return the internal ID of this JSONModel.
      def id
        ref = JSONModel::parse_reference(self.uri)

        if ref
          ref[:id]
        else
          nil
        end
      end

      # Given a hash representing a record tree, map across the hash and this
      # model's schema in lock step.
      #
      # Each proc in the 'transformations' array is called with the current node
      # in the record tree as its first argument, and the part of the schema
      # that corresponds to it.  Whatever the proc returns is used to replace
      # the node in the record tree.
      #
      def self.map_hash_with_schema(hash, schema = nil, transformations = [])
        if schema.nil?
          return self.map_hash_with_schema(hash, self.schema, transformations)
        end

        return hash if not hash.is_a?(Hash)

        if schema.is_a?(String)
          ref = JSONModel.parse_jsonmodel_ref(schema)

          if ref
            # A nested reference to another data type.  Validate against it.
            schema = JSONModel.JSONModel(ref[0]).schema
          else
            raise "Invalid schema given: #{schema}"
          end
        end

        if schema["$ref"] == "#"
          # A recursive schema.  Back to the beginning.
          schema = self.schema
        end

        return hash if not schema.has_key?("properties")

        transformations.each do |transform|
          hash = transform.call(hash, schema)
        end

        result = {}

        hash.each do |k, v|
          k = k.to_s

          if schema["properties"].has_key?(k) and (schema["properties"][k]["type"] == "object")
            result[k] = self.map_hash_with_schema(v, schema["properties"][k], transformations)
          elsif schema["properties"].has_key?(k) and (schema["properties"][k]["type"] == "array")

            if schema["properties"][k]["items"]["type"].is_a?(Array)
              # A list of multiple valid types.  Match them up based on the value of the 'jsonmodel_type' property
              schema_types = schema["properties"][k]["items"]["type"].map {|type| type["type"]}

              result[k] = v.collect {|elt|

                if elt.is_a?(Hash)
                  jsonmodel_type = elt["jsonmodel_type"]

                  if !jsonmodel_type
                    raise("Can't unambiguously match #{elt.inspect} against schema types: #{schema_types.inspect}. " +
                          "Resolve this by adding a 'jsonmodel_type' property to #{elt.inspect}")
                  end

                  next_schema = schema_types.find {|type|
                    (type.is_a?(String) && type.include?("JSONModel(:#{jsonmodel_type})")) ||
                    (type.is_a?(Hash) && type["jsonmodel_type"] === jsonmodel_type)
                  }

                  if next_schema.nil?
                    raise "Couldn't determine type of '#{elt.inspect}'.  Must be one of: #{schema_types.inspect}"
                  end

                  self.map_hash_with_schema(elt, next_schema, transformations)
                elsif elt.is_a?(Array)
                  raise "Nested arrays aren't supported here (yet)"
                else
                  elt
                end
              }
            elsif schema["properties"][k]["items"]["type"] === "object"
              result[k] = v.collect {|elt| self.map_hash_with_schema(elt, schema["properties"][k]["items"], transformations)}
            else
              # Just one valid type
              result[k] = v.collect {|elt| self.map_hash_with_schema(elt, schema["properties"][k]["items"]["type"], transformations)}
            end

          elsif schema["properties"].has_key?(k) and JSONModel.parse_jsonmodel_ref(schema["properties"][k]["type"])
            result[k] = self.map_hash_with_schema(v, schema["properties"][k]["type"], transformations)
          else
            result[k] = v
          end
        end

        result
      end


      ## Supporting methods following from here
      protected

      def self.drop_unknown_properties(hash, schema = nil)
        fn = proc do |hash, schema|
          result = {}

          hash.each do |k, v|
            if schema["properties"].has_key?(k.to_s) and v != "" and !v.nil?
              result[k] = v
            end
          end

          result
        end

        self.map_hash_with_schema(hash, schema, [fn])
      end


      def self.apply_schema_defaults(hash, schema = nil)
        fn = proc do |hash, schema|
          result = hash.clone

          schema["properties"].each do |property, definition|

            if definition.has_key?("default") and !hash.has_key?(property.to_s) and !hash.has_key?(property.intern)
              result[property] = definition["default"]
            end
          end

          result
        end

        self.map_hash_with_schema(hash, schema, [fn])
      end


      # Validate the supplied hash using the JSON schema for this model.  Raise
      # a ValidationException if there are any fatal validation problems, or if
      # strict mode is enabled and warnings were produced.
      def self.validate(hash, raise_errors = true)

        JSON::Validator.cache_schemas = true

        validator = JSON::Validator.new(self.schema,
                                        self.drop_unknown_properties(hash),
                                        :errors_as_objects => true,
                                        :record_errors => true)

        messages = validator.validate
        exceptions = JSONSchemaUtils.parse_schema_messages(messages, validator)

        if raise_errors && (!exceptions[:errors].empty? || (@@strict_mode && !exceptions[:warnings].empty?))
          raise ValidationException.new(:invalid_object => self.new(hash),
                                        :warnings => exceptions[:warnings],
                                        :errors => exceptions[:errors])
        end

        exceptions
      end


      # Given a URI template like /repositories/:repo_id/something/:somevar, and
      # a hash containing keys and replacement strings, return [uri, opts],
      # where 'uri' is the template with values substituted for their
      # placeholders, and 'opts' is any parameters that weren't consumed.
      #
      def self.substitute_parameters(uri, opts = {})
        matched = []
        opts.each do |k, v|
          old = uri
          uri = uri.gsub(":#{k}", v.to_s)

          if old != uri

            if v.is_a? Symbol
              raise ("Tried to substitute the value '#{v.inspect}' for ':#{k}'." +
                     "  This is usually a sign that something has gone wrong" +
                     " further up the stack. (URI was: '#{uri}')")
            end

            # Matched on this parameter.  Remove it from the passed in hash
            matched << k
          end
        end

        if uri.include?(":")
          raise "Template substitution was incomplete: '#{uri}'"
        end

        remaining_opts = opts.clone
        matched.each do |k|
          remaining_opts.delete(k)
        end

        [uri, remaining_opts]
      end


      # In client mode, mix in some extra convenience methods for querying the
      # ArchivesSpace backend service via HTTP.
      if @@init_args[:client_mode]
        require_relative 'jsonmodel_client'
        include JSONModel::Client
      end

    end


    cls.init(type, schema)

    cls.define_accessors(schema['properties'].keys)


    @@models[type] = cls

    cls.instance_eval do
      (@@init_args[:mixins] or []).each do |mixin|
        include(mixin)
      end
    end


  end


  def self.init_args
    @@init_args
  end

end


# Custom JSON schema validations
require_relative 'archivesspace_json_schema'
