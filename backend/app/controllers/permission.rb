class ArchivesSpaceService < Sinatra::Base

  ALLOWED_PERMISSION_LEVELS = ["repository", "global", "all"]

  Endpoint.get('/permissions')
    .description("Get a list of Permissions")
    .params(["level",
             String,
             "The permission level to get (one of: #{ALLOWED_PERMISSION_LEVELS.join(", ")})",
             :validation => ["Must be one of #{ALLOWED_PERMISSION_LEVELS.join(", ")}",
                             ->(v){ ALLOWED_PERMISSION_LEVELS.include?(v) }]])
    .permissions([])
    .returns([200, "[(:permission)]"]) \
  do
    handle_unlimited_listing(Permission,
                             (params[:level] == "all") ? {} : {:level => params[:level]})
  end

end
