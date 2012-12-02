require 'spec_helper'

describe 'Instance model' do


  it "Allows an instance to be created" do

    opts = {:instance_type => generate(:instance_type), 
            :container => build(:json_container).to_hash
            }

    instance = Instance.create_from_json(build(:json_instance, opts))

    Instance[instance[:id]].instance_type.should eq(opts[:instance_type])
    Instance[instance[:id]].container.first.type_1.should eq(opts[:container]['type_1'])
  end


end
