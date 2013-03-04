class ArchivesSpaceService < Sinatra::Base

  Endpoint.post('/repositories/:repo_id/resources')
    .description("Create a Resource")
    .params(["resource", JSONModel(:resource), "The resource to create", :body => true],
            ["repo_id", :repo_id])
    .permissions([:update_archival_record])
    .returns([200, :created],
             [400, :error]) \
  do
    handle_create(Resource, :resource)
  end


  Endpoint.get('/repositories/:repo_id/resources/:resource_id')
    .description("Get a Resource")
    .params(["resource_id", Integer, "The ID of the resource to retrieve"],
            ["repo_id", :repo_id],
            ["resolve", [String], "A list of references to resolve and embed in the response",
             :optional => true])
    .permissions([:view_repository])
    .returns([200, "(:resource)"]) \
  do
    json = Resource.to_jsonmodel(params[:resource_id])

    json_response(resolve_references(json, params[:resolve]))
  end


  Endpoint.get('/repositories/:repo_id/resources/:resource_id/tree')
    .description("Get a Resource tree")
    .params(["resource_id", Integer, "The ID of the resource to retrieve"],
            ["repo_id", :repo_id])
    .permissions([:view_repository])
    .returns([200, "OK"]) \
  do
    resource = Resource.get_or_die(params[:resource_id])

    json_response(resource.tree)
  end


  Endpoint.post('/repositories/:repo_id/resources/:resource_id')
    .description("Update a Resource")
    .params(["resource_id", Integer, "The ID of the resource to retrieve"],
            ["resource", JSONModel(:resource), "The resource to update", :body => true],
            ["repo_id", :repo_id])
    .permissions([:update_archival_record])
    .returns([200, :updated],
             [400, :error]) \
  do
    handle_update(Resource, :resource_id, :resource)
  end


  Endpoint.get('/repositories/:repo_id/resources')
    .description("Get a list of Resources for a Repository")
    .params(["repo_id", :repo_id],
            *Endpoint.pagination)
    .permissions([:view_repository])
    .returns([200, "[(:resource)]"]) \
  do
    handle_listing(Resource, params[:page], params[:page_size], params[:modified_since])
  end

end
