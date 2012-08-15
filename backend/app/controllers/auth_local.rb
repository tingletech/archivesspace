require_relative '../lib/auth_helpers'

class ArchivesSpaceService < Sinatra::Base

  include AuthHelpers

  configure do
    set :db_auth, DBAuth.new
    set :user_manager, UserManager.new
  end


  Endpoint.post('/auth/local/user/:username/login')
    .params(["username", nil, "Your username"],
            ["password", nil, "Your password"])
    .returns([200, "OK"]) \
  do
    if settings.db_auth.login(params[:username], params[:password])
      session = create_session_for(params[:username])
      json_response({:session => session.id})
    else
      json_response({:error => "Login failed"}, 403)
    end

  end


  Endpoint.post('/auth/local/user/:username/password')
    .params(["username", nil, "Username for account"],
            ["password", nil, "Password to set for account"])
    .returns([200, "OK"]) \
  do
    settings.db_auth.set_password(params[:username], params[:password])
    json_response({:status => "Updated"})
  end


  Endpoint.post('/auth/local/user/:username')
    .params(["username", nil, "Username for new account"],
            ["password", nil, "Password for new account"])
    .returns([200, "OK"]) \
  do
    begin
      settings.user_manager.create_user(params[:username], "First", "Last", "local")
      settings.db_auth.set_password(params[:username], params[:password])
      "OK"
    rescue Sequel::DatabaseError => ex
      if DB.is_integrity_violation(ex)
        raise ConflictException.new("That username is already in use")
      end
    end
  end

end
