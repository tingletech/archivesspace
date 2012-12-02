require 'net/http'
require 'json'
require_relative 'exceptions'


module JSONModel

  # Set the repository that subsequent operations will apply to.
  def self.set_repository(id)
    Thread.current[:selected_repo_id] = id
  end


  # Grab an array of JSON objects from 'uri' and use the 'type_descriptor'
  # property of each object to cast it into a JSONModel.
  def self.all(uri, type_descriptor)
    JSONModel::HTTP.get_json(uri).map do |obj|
      JSONModel(obj[type_descriptor.to_s]).from_hash(obj)
    end
  end


  def self.with_repository(id)
    old_repo = Thread.current[:selected_repo_id]
    begin
      self.set_repository(id)
      yield
    ensure
      self.set_repository(old_repo)
    end
  end


  def self.backend_url
    if Module.const_defined?(:BACKEND_SERVICE_URL)
      BACKEND_SERVICE_URL
    else
      init_args[:url]
    end
  end


  @@error_handlers = []

  def self.add_error_handler(&block)
    @@error_handlers << block
  end

  def self.handle_error(err)
    @@error_handlers.each do |handler|
      handler.call(err)
    end
  end


  @@protected_fields << "uri"


  module Webhooks
    @@notification_handlers = []

    def self.add_notification_handler(code = nil, &block)
      @@notification_handlers << {:code => code, :block => block}
    end

    def self.notify(notification)
      notification.events.each do |event|
        @@notification_handlers.each do |handler|
          if handler[:code].nil? or handler[:code] == event["code"]
            handler[:block].call(event["code"], event["params"])
          end
        end
      end
    end

    def self.webhook_register(endpoint)
      JSONModel::HTTP::post_form('/webhooks/register', "url" => endpoint)
    end
  end



  module HTTP

    def self.backend_url
      if Module.const_defined?(:BACKEND_SERVICE_URL)
        BACKEND_SERVICE_URL
      else
        JSONModel::init_args[:url]
      end
    end


    # Perform a HTTP POST request against the backend with form parameters
    def self.post_form(uri, params = {})
      url = URI("#{backend_url}#{uri}")

      req = Net::HTTP::Post.new(url.request_uri)
      req.form_data = params

      do_http_request(url, req)
    end


    def self.get_json(uri, params = {})
      uri = URI("#{backend_url}#{uri}")
      uri.query = URI.encode_www_form(params)

      response = get_response(uri)

      if response.is_a?(Net::HTTPSuccess) || response.status == 200
        JSON.parse(response.body, :max_nesting => false)
      else
        nil
      end
    end


    # Returns the session token to be sent to the backend when making
    # requests.
    def self.current_backend_session
      # Set by the ApplicationController
      Thread.current[:backend_session]
    end


    def self.current_backend_session=(val)
      Thread.current[:backend_session] = val
    end

    def self.do_http_request(url, req)
      req['X-ArchivesSpace-Session'] = current_backend_session

      Net::HTTP.start(url.host, url.port) do |http|
        response = http.request(req)

        if response.code =~ /^4/
          JSONModel::handle_error(JSON.parse(response.body, :max_nesting => false))
        end

        response
      end
    end


    def self.post_json(url, json)
      req = Net::HTTP::Post.new(url.request_uri)
      req['Content-Type'] = 'text/json'
      req.body = json

      do_http_request(url, req)
    end


    def self.get_response(url)
      req = Net::HTTP::Get.new(url.request_uri)

      do_http_request(url, req)
    end

  end



  module Client

    def self.included(base)
      base.extend(ClassMethods)
    end


    # Validate this JSONModel instance, produce a JSON string, and send an
    # update to the backend.
    def save(opts = {})

      @errors = nil

      type = self.class.record_type
      response = JSONModel::HTTP.post_json(self.class.my_url(self.id, opts),
                                           self.to_json)

      if response.code == '200'
        response = JSON.parse(response.body, :max_nesting => false)

        self.uri = self.class.uri_for(response["id"], opts)

        # If we were able to save successfully, increment our local version
        # number to match the version on the server.
        self.lock_version = response["lock_version"]

        # Ensure object is up to date
        if response["stale"]
          self.refetch
        end

        return response["id"]

      elsif response.code == '403'
        raise AccessDeniedException.new

      elsif response.code == '409'
        err = JSON.parse(response.body)
        raise ConflictException.new(err["error"])

      elsif response.code =~ /^4/
        err = JSON.parse(response.body)

        @errors = err["error"]

        raise ValidationException.new(:invalid_object => self,
                                      :errors => err["error"])
      else
        raise Exception.new("Unknown response: #{response}")
      end
    end


    def refetch
      # if a new object, nothing to fetch
      return self if self.id.nil?

      obj = (self.instance_data.has_key? :find_opts) ?
                self.class.find(self.id, self.instance_data[:find_opts]) : self.class.find(self.id)

      self.reset_from(obj) if not obj.nil?
    end


    # Mark the suppression status of this record
    def set_suppressed(val)
      response = JSONModel::HTTP.post_form("#{self.uri}/suppressed", :suppressed => val)

      if response.code == '403'
        raise AccessDeniedException.new("Permission denied when setting suppression status")
      elsif response.code != '200'
        raise "Error when setting suppression status for #{self}: #{response.code} -- #{response.body}"
      end

      self["suppressed"] = JSON.parse(response.body)["suppressed_state"]
    end


    def suppress
      set_suppressed(true)
    end


    def unsuppress
      set_suppressed(false)
    end


    def add_error(field, message)
      @errors ||= {}
      @errors[field.to_s] ||= []
      @errors[field.to_s] << message
    end


    module ClassMethods

      def self.extended(base)
        class << base
          alias :_substitute_parameters :substitute_parameters

          def substitute_parameters(uri, opts = {})
            if not opts.has_key?(:repo_id)
              opts = opts.clone
              opts[:repo_id] = Thread.current[:selected_repo_id]
            end

            _substitute_parameters(uri, opts)
          end
        end
      end


      # Given the ID of a JSONModel instance, return its full URL (including the
      # URL of the backend)
      def my_url(id = nil, opts = {})

        uri, remaining_opts = self.uri_and_remaining_options_for(id, opts)

        url = URI("#{JSONModel::HTTP.backend_url}#{uri}")

        # Don't need to pass this as a URL parameter if it wasn't picked up by
        # the URI template substitution.
        remaining_opts.delete(:repo_id)

        if not remaining_opts.empty?
          url.query = URI.encode_www_form(remaining_opts)
        end

        url
      end


      # Given an ID, retrieve an instance of the current JSONModel from the
      # backend.
      def find(id, opts = {})
        response = JSONModel::HTTP.get_response(my_url(id, opts))

        if response.code == '200'
          obj = self.from_json(response.body)
          # store find params on instance to support #refetch
          obj.instance_data[:find_opts] = opts
          obj
        elsif response.code == '403'
          raise AccessDeniedException.new
        elsif response.code == '404'
          nil
        else
          raise response.body
        end
      end


      # Return all instances of the current JSONModel's record type.
      def all(params = {}, opts = {})
        uri = my_url(nil, opts)

        uri.query = URI.encode_www_form(params)

        response = JSONModel::HTTP.get_response(uri)

        if response.code == '200'
          json_list = JSON.parse(response.body, :max_nesting => false)

          if json_list.is_a?(Hash)
            json_list["results"] = json_list["results"].map {|h| self.from_hash(h)}
          else
            json_list = json_list.map {|h| self.from_hash(h)}
          end

          json_list
        elsif response.code == '403'
          raise AccessDeniedException.new
        else
          raise response.body
        end
      end

    end

  end
end
