module RESTHelpers

  include JSONModel


  def resolve_reference(reference)
    if !reference.is_a? Hash
      raise "Argument must be a {'ref' => '/uri'} hash (not: #{reference})"
    end

    if JSONModel.parse_reference(reference['ref'])
      record = redirect_internal(reference['ref'])[2].body.join("")
      reference.clone.merge('_resolved' => JSON.parse(record, :max_nesting => false))
    else
      raise "Couldn't parse ref: #{reference.inspect}"
    end
  end


  def resolve_references(value, properties_to_resolve)
    value = value.to_hash if value.respond_to?(:to_hash)

    # If ASPACE_REENTRANT is set, don't resolve anything or we risk creating loops.
    return value if (properties_to_resolve.nil? || env['ASPACE_REENTRANT'])

    if value.is_a? Hash
      result = value.clone

      value.each do |k, v|
        if properties_to_resolve.include?(k)
          result[k] = (v.is_a? Array) ? v.map {|elt| resolve_reference(elt)} : resolve_reference(v)
        else
          result[k] = resolve_references(v, properties_to_resolve)
        end
      end

      result

    elsif value.is_a? Array
      value.map {|elt| resolve_references(elt, properties_to_resolve)}
    else
      value
    end
  end


  module ResponseHelpers

    # Redispatch the current request to a different route handler.
    def redirect_internal(url)
      call env.merge("PATH_INFO" => url, "ASPACE_REENTRANT" => true)
    end


    def json_response(obj, status = 200)
      [status, {"Content-Type" => "application/json"}, [obj.to_json(:max_nesting => false) + "\n"]]
    end


    def modified_response(type, obj, jsonmodel = nil)
      response = {:status => type, :id => obj[:id], :lock_version => obj[:lock_version], :stale => obj.system_modified?}

      if jsonmodel
        response[:uri] = jsonmodel.class.uri_for(obj[:id], params)
        response[:warnings] = jsonmodel._warnings
      end

      json_response(response)
    end


    def created_response(*opts)
      modified_response('Created', *opts)
    end


    def updated_response(*opts)
      modified_response('Updated', *opts)
    end

    def deleted_response(id)
      json_response({:status => 'Deleted', :id => id})
    end


    def suppressed_response(id, state)
      json_response({:status => 'Suppressed', :id => id, :suppressed_state => state})
    end

  end


  class Endpoint

    @@endpoints = []


    @@param_types = {
      :repo_id => [Integer,
                   "The Repository ID",
                   {:validation => ["The Repository must exist", ->(v){Repository.exists?(v)}]}]
    }

    @@return_types = {
      :created => '{:status => "Created", :id => (id of created object), :warnings => {(warnings)}}',
      :updated => '{:status => "Updated", :id => (id of updated object)}',
      :suppressed => '{:status => "Suppressed", :id => (id of updated object), :suppressed_state => (true|false)}',
      :error => '{:error => (description of error)}'
    }

    def initialize(method)
      @method = method
      @uri = ""
      @description = "-- No description provided --"
      @permissions = []
      @preconditions = []
      @required_params = []
      @returns = []
    end

    def [](key)
      if instance_variable_defined?("@#{key}")
        instance_variable_get("@#{key}")
      end
    end

    def self.pagination
      [["page_size",
        PageSize,
        "The number of results to show per page",
        :default => 10],
       ["page", NonNegativeInteger, "The page number to show"],
       ["modified_since",
        NonNegativeInteger,
        "Only include results with a modified date after this timestamp",
        :default => 0]]
    end

    def self.all
      @@endpoints.map do |e|
        e.instance_eval do
          {
            :uri => @uri,
            :description => @description,
            :method => @method,
            :params => @required_params,
            :returns => @returns
          }
        end
      end
    end

    def self.get(uri); self.method(:get).uri(uri); end
    def self.post(uri); self.method(:post).uri(uri); end
    def self.delete(uri); self.method(:delete).uri(uri); end
    def self.method(method); Endpoint.new(method); end

    def uri(uri); @uri = uri; self; end
    def description(description); @description = description; self; end
    def preconditions(*preconditions); @preconditions += preconditions; self; end


    def permissions(permissions)
      @has_permissions = true

      permissions.each do |permission|
        @preconditions << proc { |request| current_user.can?(permission) }
      end

      self
    end


    # Just some scaffolding until everything has permissions specified
    def nopermissionsyet
      @has_permissions = true
      Log.warn("No permissions defined for #{@method.upcase} #{@uri}")
      self
    end


    def params(*params)
      @required_params = params.map do |p|
        @@param_types[p[1]] ? [p[0], @@param_types[p[1]]].flatten : p
      end

      self
    end


    def returns(*returns, &block)
      raise "No .permissions declaration for endpoint #{@method.to_s.upcase} #{@uri}" if !@has_permissions

      @returns = returns.map { |r| r[1] = @@return_types[r[1]] || r[1]; r }

      @@endpoints << self

      preconditions = @preconditions
      rp = @required_params
      uri = @uri
      method = @method

      if ArchivesSpaceService.development?
        # Undefine any pre-existing routes (sinatra reloader seems to have trouble
        # with this for our instances)
        ArchivesSpaceService.instance_eval {
          new_route = compile(uri)

          if @routes[method.to_s.upcase]
            @routes[method.to_s.upcase].reject! do |route|
              route[0..1] == new_route
            end
          end
        }
      end

      ArchivesSpaceService.send(@method, @uri, {}) do

        ensure_params(rp)

        Log.debug("Post-processed params: #{Log.filter_passwords(params).inspect}")

        RequestContext.open(:repo_id => params[:repo_id],
                            :is_high_priority => high_priority_request?) do
          unless preconditions.all? { |precondition| self.instance_eval &precondition }
            raise AccessDeniedException.new("Access denied")
          end

          result = DB.open do

            RequestContext.put(:current_username, current_user.username)

            # If the current user is a manager, show them suppressed records
            # too.
            if RequestContext.get(:repo_id)
              RequestContext.put(:enforce_suppression,
                                 !(current_user.can?(:manage_repository) ||
                                   current_user.can?(:view_suppressed) ||
                                   current_user.can?(:suppress_archival_record)))
            end

            self.instance_eval &block
          end
        end
      end
    end
  end


  class NonNegativeInteger
    def self.value(s)
      val = Integer(s)

      if val < 0
        raise ArgumentError.new("Invalid non-negative integer value: #{s}")
      end

      val
    end
  end


  class PageSize
    def self.value(s)
      val = Integer(s)

      if val < 0
        raise ArgumentError.new("Invalid non-negative integer value: #{s}")
      end

      if val > AppConfig[:max_page_size].to_i
        Log.warn("Requested page size of #{val} exceeds the maximum allowable of #{AppConfig[:max_page_size]}." +
                 "  It has been reduced to the maximum.")

        val = AppConfig[:max_page_size].to_i
      end

      val
    end
  end


  class BooleanParam
    def self.value(s)
      if s.nil?
        nil
      elsif s.downcase == 'true'
        true
      elsif s.downcase == 'false'
        false
      else
        raise ArgumentError.new("Invalid boolean value: #{s}")
      end
    end
  end


  def self.included(base)

    base.extend(JSONModel)

    base.helpers do

      def coerce_type(value, type)
        if type == Integer
          Integer(value)
        elsif type.respond_to? :from_json
          type.from_json(value)
        elsif type.is_a? Array
          if value.is_a? Array
            value.map {|elt| coerce_type(elt, type[0])}
          else
            raise ArgumentError.new("Not an array")
          end
        elsif type.is_a? Regexp
          raise ArgumentError.new("Value '#{value}' didn't match #{type}") if value !~ type
          value
        elsif type.respond_to? :value
          type.value(value)
        else
          value
        end
      end


      def ensure_params(declared_params)

        errors = {
          :missing => [],
          :bad_type => [],
          :failed_validation => []
        }

        known_params = {}

        declared_params.each do |definition|

          (name, type, doc, opts) = definition
          opts ||= {}

          known_params[name] = true

          if opts[:body]
            params[name] = request.body.read
          end

          if not params[name] and not opts[:optional] and not opts[:default]
            errors[:missing] << {:name => name, :doc => doc}
          else

            if type and params[name]
              begin
                params[name.intern] = coerce_type(params[name], type)
                params.delete(name)

              rescue ArgumentError
                errors[:bad_type] << {:name => name, :doc => doc, :type => type}
              end
            elsif type and opts[:default]
              params[name.intern] = opts[:default]
              params.delete(name)
            end

            if opts[:validation]
              if not opts[:validation][1].call(params[name.intern])
                errors[:failed_validation] << {:name => name, :doc => doc, :type => type, :validation => opts[:validation][0]}
              end
            end

          end
        end


        # Any params that were passed in that aren't declared by our endpoint get dropped here.
        unknown_params = params.keys.reject {|p| known_params[p.to_s] }

        unknown_params.each do |p|
          params.delete(p)
        end


        if not errors.values.flatten.empty?
          result = {}

          errors[:missing].each do |missing|
            result[missing[:name]] = ["Parameter required but no value provided"]
          end

          errors[:bad_type].each do |bad|
            result[bad[:name]] = ["Wanted type #{bad[:type]} but got '#{params[bad[:name]]}'"]
          end

          errors[:failed_validation].each do |failed|
            result[failed[:name]] = ["Failed validation -- #{failed[:validation]}'"]
          end

          raise BadParamsException.new(result)
        end
      end
    end
  end

end
