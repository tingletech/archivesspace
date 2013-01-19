require_relative "../../../migrations/lib/crosswalk"

module ImportHelpers
  
  def handle_import
    batch = Batch.new(params[:batch_import])
    
    RequestContext.put(:repo_id, params[:repo_id])

    begin 
      batch.process
      json_response({:saved => batch.saved_uris}, 200)
    end
  end  
  
  class Batch
    attr_accessor :saved_uris
    
    def initialize(batch_object)
      @json_set, @as_set, @saved_uris = {}, {}, {}
      
      batch_object.batch.each do |item|
         @json_set[item['uri']] = JSONModel::JSONModel(item['jsonmodel_type']).from_hash(item)
      end
      
    end
      
    # 1. Create ASModel objects from the JSONModel objects minus the references
    # 2. Update the nonce URIs of the JSONModel objects using their DB IDs
    # 3. Update JSONModel links using the real URIs
    # 4. Update ASModels with JSONModels with their references

    def process

      @json_set.each do |ref, json|
      
        unlinked = self.class.unlink(json)
        
        begin
        obj = Kernel.const_get(json.class.record_type.camelize).create_from_json(unlinked)
        @as_set[json.uri] = [obj.id, obj.class]
        
        # Now update the URI with the real ID
        json.uri.sub!(/\/[0-9]+$/, "/#{@as_set[json.uri][0].to_s}")
        rescue Exception => e
          raise ImportException.new({:invalid_object => json, :message => e.message})
        end
      end
         
      # Update the linked record pointers in the json set
      @json_set.each do |ref, json|
        ASpaceImport::Crosswalk.update_record_references(json, @json_set) {|referenced| referenced.uri}
      end
          
      @as_set.each do |ref, a|
        obj = a[1].get_or_die(a[0])    
        obj.update_from_json(@json_set[ref], {:lock_version => obj.lock_version}) 
        @saved_uris[ref] = @json_set[ref].uri   
      end
    end
    
    
    def self.unlink_key?(kdef, v)
      key_type = ASpaceImport::Crosswalk.get_property_type(kdef)[0]
      return true if key_type == :record_uri && v.is_a?(String) && !v.match(/\/vocabularies\/[0-9]+$/)
      return true if key_type == :record_uri_or_record_inline && v.is_a?(String)
      return true if key_type == :record_uri_or_record_inline_list && v[0].is_a?(String)
      return true if key_type.match(/^record_ref/)
      false
    end


    def self.unlink(json)
      unlinked = json.clone
      data = unlinked.to_hash
      data.each { |k, v| data.delete(k) if self.unlink_key?(json.class.schema["properties"][k], v) }

      unlinked.set_data(data)
      unlinked
    end
  end


  class ImportException < StandardError
    attr_accessor :invalid_object
    attr_accessor :message

    def initialize(opts)
      @invalid_object = opts[:invalid_object]
      @message = opts[:message]
    end

    def to_s
      "#<:ImportException: #{{:invalid_object => @invalid_object, :message => @message}.inspect}>"
    end
  end

end


 
