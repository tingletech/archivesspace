class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/repositories/:repo_id/digital_objects/:digital_object_id')
    .description("Get a Digital Object")
    .params(["digital_object_id", Integer, "The ID of the digital object to retrieve"],
            ["repo_id", :repo_id],
            ["resolve", [String], "A list of references to resolve and embed in the response",
             :optional => true])
    .permissions([:view_repository])
    .returns([200, "(:digital_object)"]) \
  do
    json = DigitalObject.to_jsonmodel(params[:digital_object_id])

    json_response(resolve_references(json, params[:resolve]))
  end


  Endpoint.post('/repositories/:repo_id/digital_objects')
    .description("Create a Digital Object")
    .params(["digital_object", JSONModel(:digital_object), "The digital object to create", :body => true],
            ["repo_id", :repo_id])
    .permissions([:update_archival_record])
    .returns([200, :created],
             [400, :error]) \
  do
    handle_create(DigitalObject, :digital_object)
  end


  Endpoint.post('/repositories/:repo_id/digital_objects/:digital_object_id')
    .description("Update a Digital Object")
    .params(["digital_object_id", Integer, "The ID of the digital object to retrieve"],
            ["digital_object", JSONModel(:digital_object), "The digital object to update", :body => true],
            ["repo_id", :repo_id])
    .permissions([:update_archival_record])
    .returns([200, :updated],
             [400, :error]) \
  do
    handle_update(DigitalObject, :digital_object_id, :digital_object)
  end


  Endpoint.get('/repositories/:repo_id/digital_objects')
    .description("Get a list of Digital Objects for a Repository")
    .params(["repo_id", :repo_id],
            *Endpoint.pagination)
    .permissions([:view_repository])
    .returns([200, "[(:digital_object)]"]) \
  do
    handle_listing(DigitalObject, params[:page], params[:page_size], params[:modified_since])
  end


  Endpoint.get('/repositories/:repo_id/digital_objects/:digital_object_id/tree')
    .description("Get a Digital Object tree")
    .params(["digital_object_id", Integer, "The ID of the digital object to retrieve"],
            ["repo_id", :repo_id])
    .permissions([:view_repository])
    .returns([200, "OK"]) \
  do
    digital_object = DigitalObject.get_or_die(params[:digital_object_id])

    json_response(digital_object.tree)
  end

end
