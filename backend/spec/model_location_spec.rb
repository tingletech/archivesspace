require 'spec_helper'

describe 'Location model' do

  it "can be created from a JSON module" do
    location = Location.create_from_json(build(:json_location), :repo_id => $repo_id)

    Location[location[:id]].building.should eq("129 West 81st Street")
    Location[location[:id]].barcode.should match(/[0,1]?/)
  end


  it "can be created with coordinate data" do
    opts = {:coordinate_1_label => "Position XYZ",
            :coordinate_1_indicator => "A1BB99",
            :coordinate_2_label => "Position ABC",
            :coordinate_2_indicator => "Z55"}
    
    location = Location.create_from_json(build(:json_location, opts), :repo_id => $repo_id)

    Location[location[:id]].building.should eq("129 West 81st Street")
    Location[location[:id]].coordinate_1_label.should eq("Position XYZ")
    Location[location[:id]].coordinate_2_indicator.should eq("Z55")
  end


  it "can be created with a classification" do
    opts = {:classification => "Foo Foo Foo Foo"}
    
    location = Location.create_from_json(build(:json_location, opts), :repo_id => $repo_id)

    Location[location[:id]].building.should eq("129 West 81st Street")
    Location[location[:id]].classification.should eq("Foo Foo Foo Foo")
  end


  it "generates a title" do

    building = "1 Testing Street"
    barcode = "011011001"

    location = Location.create_from_json(build(:json_location, {:building => building, :barcode => barcode, :floor => nil, :room => nil}), :repo_id => $repo_id)

    Location[location[:id]].title.should eq("#{building} [#{barcode}]")
  end


  it "enforces at least one of barcode, classification or coordinate" do
    expect {
      create(:json_location, {:barcode => nil, :classification => nil, :coordinate_1_indicator => nil})
    }.to raise_error(ValidationException)
  end

end
