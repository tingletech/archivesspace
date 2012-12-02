require 'spec_helper'

describe 'Generic agent controller' do

  it "lets you list all agents of any type" do
    [
      :agent_person, 
      :agent_family, 
      :agent_software, 
      :agent_corporate_entity
    ].each do |a_type|
      
      JSONModel.all('/agents', :agent_type).map {|agent| agent.agent_type }.should_not include(a_type.to_s)

      create("json_#{a_type.to_s}".to_sym)

      JSONModel.all('/agents', :agent_type).map {|agent| agent.agent_type }.should include(a_type.to_s)
    end

  end


  it "lets you list a queried set of agents" do
    create(:json_agent_person)

    name = build(:json_name_family).to_hash
    create(:json_agent_family, :names => [name])

    agents = JSONModel::HTTP.get_json("/agents/by-name", {:q => name['sort_name']})

    agents.length.should eq(1)
    agents[0]["names"][0]["sort_name"].should eq(name['sort_name'])
  end
end
