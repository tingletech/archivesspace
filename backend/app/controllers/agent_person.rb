class ArchivesSpaceService < Sinatra::Base

  Endpoint.post('/agents/people')
    .description("Create a person agent")
    .params(["agent", JSONModel(:agent_person), "The person to create", :body => true])
    .returns([200, :created],
             [400, :error]) \
  do
    handle_create(AgentPerson, :agent)
  end


  Endpoint.post('/agents/people/:agent_id')
    .description("Update a person agent")
    .params(["agent_id", Integer, "The ID of the agent to update"],
            ["agent", JSONModel(:agent_person), "The person to create", :body => true])
    .returns([200, :updated],
             [400, :error]) \
  do
    handle_update(AgentPerson, :agent_id, :agent)
  end


  Endpoint.get('/agents/people/:id')
    .description("Get a person by ID")
    .params(["id", Integer, "ID of the person agent"])
    .returns([200, "(:agent)"],
             [404, '{"error":"Agent not found"}']) \
  do
    json_response(AgentPerson.to_jsonmodel(AgentPerson.get_or_die(params[:id]),
                                           :agent_person))
  end

end
