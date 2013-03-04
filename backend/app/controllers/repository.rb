class ArchivesSpaceService < Sinatra::Base

  Endpoint.post('/repositories')
    .description("Create a Repository")
    .params(["repository", JSONModel(:repository), "The repository to create", :body => true])
    .permissions([:create_repository])
    .returns([200, :created],
             [400, :error],
             [403, :access_denied]) \
  do
    handle_create(Repository, :repository)
  end


  Endpoint.get('/repositories/:id')
    .description("Get a Repository by ID")
    .params(["id", Integer, "ID of the repository"])
    .permissions([])
    .returns([200, "(:repository)"],
             [404, '{"error":"Repository not found"}']) \
  do
    json_response(Repository.to_jsonmodel(Repository.get_or_die(params[:id])))
  end


  Endpoint.get('/repositories')
    .description("Get a list of Repositories")
    .permissions([])
    .returns([200, "[(:repository)]"]) \
  do
    handle_unlimited_listing(Repository, :hidden => 0)
  end

end
