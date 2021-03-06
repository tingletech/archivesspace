class ArchivesSpaceService < Sinatra::Base

  Endpoint.get('/repositories/:repo_id/search')
    .description("Search this repository")
    .params(["repo_id", :repo_id],
            ["q", String, "A search query string"],
            ["type",
             [String],
             "The record type to search (defaults to all types if not specified)",
             :optional => true],
            ["exclude",
             [String],
             "A list of document IDs that should be excluded from results",
             :optional => true],
            *Endpoint.pagination)
    .permissions([:view_repository])
    .returns([200, "[(:location)]"]) \
  do
    show_suppressed = !RequestContext.get(:enforce_suppression)

    json_response(Solr.search(params[:q], params[:page], params[:page_size],
                              params[:repo_id],
                              params[:type], show_suppressed, params[:exclude]))
  end

  Endpoint.get('/search')
  .description("Search this archive")
  .params(["q", String, "A search query string"],
          ["type",
           [String],
           "The record type to search (defaults to all types if not specified)",
           :optional => true],
          ["exclude",
           [String],
           "A list of document IDs that should be excluded from results",
           :optional => true],
          *Endpoint.pagination)
  .nopermissionsyet
  .returns([200, "[(:location)]"]) \
  do
    show_suppressed = !RequestContext.get(:enforce_suppression)

    json_response(Solr.search(params[:q], params[:page], params[:page_size],
                              nil,
                              params[:type], show_suppressed, params[:exclude]))
  end

end
