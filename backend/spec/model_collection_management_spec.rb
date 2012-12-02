require 'spec_helper'

describe 'Collection Management model' do

  it "supports creating a new Collection Management record" do
    create(:json_collection_management, :cataloged_note => "An optional note")
    cm = CollectionManagement.find(:cataloged_note => "An optional note")
    cm.should_not be_nil
  end


  it "enforces one linked accession or resource, or one or more digital objects" do

    expect {
      create(:json_collection_management,
             :linked_records => [{'ref' => create(:json_accession).uri}])
    }.to_not raise_error(JSONModel::ValidationException)

    expect {
      create(:json_collection_management,
             :linked_records => [{'ref' => create(:json_resource).uri}])
    }.to_not raise_error(JSONModel::ValidationException)

    expect {
      create(:json_collection_management,
             :linked_records => [{'ref' => create(:json_digital_object).uri},
                                 {'ref' => create(:json_digital_object).uri},
                                 {'ref' => create(:json_digital_object).uri}])
    }.to_not raise_error(JSONModel::ValidationException)

    expect {
      create(:json_collection_management, :linked_records => [])
    }.to raise_error(JSONModel::ValidationException)

    expect {
      create(:json_collection_management,
             :linked_records => [{'ref' => create(:json_accession).uri},
                                 {'ref' => create(:json_accession).uri}])
    }.to raise_error(JSONModel::ValidationException)

    expect {
      create(:json_collection_management,
             :linked_records => [{'ref' => create(:json_resource).uri},
                                 {'ref' => create(:json_resource).uri}])
    }.to raise_error(JSONModel::ValidationException)

    expect {
      create(:json_collection_management,
             :linked_records => [{'ref' => create(:json_accession).uri},
                                 {'ref' => create(:json_digital_object).uri}])
    }.to raise_error(JSONModel::ValidationException)

  end

end
