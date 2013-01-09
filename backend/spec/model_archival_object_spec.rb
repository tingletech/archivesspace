require 'spec_helper'

describe 'ArchivalObject model' do

  it "Allows archival objects to be created" do
    ao = ArchivalObject.create_from_json(
                                          build(
                                                :json_archival_object,
                                                :title => 'A new archival object'
                                                ),
                                          :repo_id => $repo_id)

    ArchivalObject[ao[:id]].title.should eq('A new archival object')
  end


  it "Allow multiple archival objects to be created without conflicts" do
    create_list(:json_archival_object, 5)
  end


  it "Allows archival objects to be created with an extent" do
    
    opts = {:extents => [{
      "portion" => "whole",
      "number" => "5 or so",
      "extent_type" => generate(:extent_type),
    }]}
    
    ao = ArchivalObject.create_from_json(
                                          build(:json_archival_object, opts),
                                          :repo_id => $repo_id)
    ArchivalObject[ao[:id]].extent.length.should eq(1)
    ArchivalObject[ao[:id]].extent[0].extent_type.should eq(opts[:extents][0]['extent_type'])
  end


  it "Allows archival objects to be created with a date" do
    
    opts = {:dates => [{
         "date_type" => "single",
         "label" => "creation",
         "begin" => generate(:yyyy_mm_dd),
         "end" => generate(:yyyy_mm_dd),
      }]}
    
    ao = ArchivalObject.create_from_json(
                                          build(:json_archival_object, opts),
                                          :repo_id => $repo_id)

    ArchivalObject[ao[:id]].date.length.should eq(1)
    ArchivalObject[ao[:id]].date[0].begin.should eq(opts[:dates][0]['begin'])
  end


  it "Allows archival objects to be created with an instance" do
    
    opts = {:instances => [{
         "instance_type" => generate(:instance_type),
         "container" => build(:json_container).to_hash
       }]}
    
       ao = ArchivalObject.create_from_json(
                                             build(:json_archival_object, opts),
                                             :repo_id => $repo_id)

    ArchivalObject[ao[:id]].instance.length.should eq(1)
    ArchivalObject[ao[:id]].instance[0].instance_type.should eq(opts[:instances][0]['instance_type'])
    ArchivalObject[ao[:id]].instance[0].container.first.type_1.should eq(opts[:instances][0]['container']['type_1'])
  end


  it "will generate a ref_id if non is provided" do
    ao = ArchivalObject.create_from_json(build(:json_archival_object),
                                         :repo_id => $repo_id)

    ArchivalObject[ao[:id]].ref_id.should_not be_nil
  end


  it "throws an error if 'level' is 'otherlevel' and 'other level' isn't provided" do

    opts = {:level => "otherlevel", :other_level => nil}

    expect { ArchivalObject.create_from_json(
                                build(:json_archival_object, opts),
                                :repo_id => $repo_id)
    }.to raise_error
  end

end
