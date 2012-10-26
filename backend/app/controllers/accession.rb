class ArchivesSpaceService < Sinatra::Base

  Endpoint.post('/repositories/:repo_id/accessions/:accession_id')
    .description("Update an Accession")
    .params(["accession_id", Integer, "The accession ID to update"],
            ["accession", JSONModel(:accession), "The accession data to update", :body => true],
            ["repo_id", :repo_id])
    .returns([200, :updated]) \
  do
    handle_update(Accession, :accession_id, :accession,
                  :repo_id => params[:repo_id])
  end


  Endpoint.post('/repositories/:repo_id/accessions')
    .description("Create an Accession")
    .params(["accession", JSONModel(:accession), "The accession to create", :body => true],
            ["repo_id", :repo_id])
    .returns([200, :created]) \
  do
    handle_create(Accession, :accession)
  end


  Endpoint.get('/repositories/:repo_id/accessions')
    .description("Get a list of Accessions for a Repository")
    .params(["repo_id", :repo_id])
    .returns([200, "[(:accession)]"]) \
  do
    handle_listing(Accession, :accession, :repo_id => params[:repo_id])
  end


  Endpoint.get('/repositories/:repo_id/accessions/:accession_id')
    .description("Get an Accession by ID")
    .params(["accession_id", Integer, "The accession ID"],
            ["repo_id", :repo_id],
            ["resolve", [String], "A list of references to resolve and embed in the response",
             :optional => true])
    .returns([200, "(:accession)"]) \
  do
    json = Accession.to_jsonmodel(params[:accession_id], :accession, params[:repo_id])

    json_response(resolve_references(json.to_hash, params[:resolve]))
  end
end
