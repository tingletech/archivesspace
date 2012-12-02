class ArchivesSpaceService < Sinatra::Base

  Endpoint.post('/agents/families')
    .description("Create a family agent")
    .params(["agent", JSONModel(:agent_family), "The family to create", :body => true])
    .returns([200, :created],
             [400, :error]) \
  do
    handle_create(AgentFamily, :agent)
  end


  Endpoint.post('/agents/families/:agent_id')
    .description("Update a family agent")
    .params(["agent_id", Integer, "The ID of the agent to update"],
            ["agent", JSONModel(:agent_family), "The family to create", :body => true])
    .returns([200, :updated],
             [400, :error]) \
  do
    handle_update(AgentFamily, :agent_id, :agent)
  end


  Endpoint.get('/agents/families/:id')
    .description("Get a family by ID")
    .params(["id", Integer, "ID of the family agent"])
    .returns([200, "(:agent)"],
             [404, '{"error":"Agent not found"}']) \
  do
    json_response(AgentFamily.to_jsonmodel(AgentFamily.get_or_die(params[:id]),
                                           :agent_family))
  end

end
