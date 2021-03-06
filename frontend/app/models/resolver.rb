class Resolver


  def initialize(uri)
    @uri = uri

    jsonmodel_properties = JSONModel.parse_reference(@uri)

    @id = jsonmodel_properties[:id]
    @repo_id = jsonmodel_properties[:repo_id]
    @jsonmodel_type = jsonmodel_properties[:type]
  end


  def edit_uri
    uri_properties = default_uri_properties

    uri_properties[:action] = :edit

    uri_properties
  end


  def view_uri
    uri_properties = default_uri_properties

    uri_properties[:action] = :show

    uri_properties
  end


  private
  
  def default_uri_properties
    uri_properties = {
      :controller => @jsonmodel_type.to_s.pluralize.intern,
      :id => @id
    }

    if @jsonmodel_type.start_with? "agent_"
      uri_properties[:controller] = :agents
      uri_properties[:type] = @jsonmodel_type
    elsif @jsonmodel_type === "archival_object"
      ao = JSONModel(:archival_object).find(@id)
      uri_properties[:controller] = :resources
      uri_properties[:id] = JSONModel(:resource).id_for(ao["resource"])
      uri_properties[:anchor] = "tree::archival_object_#{@id}"
    elsif @jsonmodel_type === "digital_object_component"
      doc = JSONModel(:digital_object_component).find(@id)
      uri_properties[:controller] = :digital_objects
      uri_properties[:id] = JSONModel(:digital_object).id_for(doc["digital_object"])
      uri_properties[:anchor] = "tree::digital_object_component_#{@id}"
    end

    uri_properties
  end

end
