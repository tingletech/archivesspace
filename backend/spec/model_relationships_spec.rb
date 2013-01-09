require 'spec_helper'
require_relative '../app/model/ASModel'
require_relative '../app/model/relationships'

describe 'Relationships' do

  before(:each) do
    ## Database setup
    DB.open do |db|
      [:apple, :banana].each do |table|
        db.create_table table do
          primary_key :id
          String :name
          Integer :lock_version, :default => 0
          Date :create_time
          Date :last_modified
        end
      end

      db.create_table :app_fruit_salad_ban do
        primary_key :id
        String :sauce
        Integer :banana_id
        Integer :apple_id
        Integer :aspace_relationship_position
      end
    end
  end


  after(:each) do
    DB.open do |db|
      db.drop_table(:apple)
      db.drop_table(:banana)
      db.drop_table(:app_fruit_salad_ban)
    end
  end


  before(:each) do
    ## Some minimal JSONModel instances
    JSONModel.stub(:schema_src).with('apple').and_return('{
      :schema => {
        "$schema" => "http://www.archivesspace.org/archivesspace.json",
        "type" => "object",
        "uri" => "/apples",
        "properties" => {
          "uri" => {"type" => "string", "required" => false},
          "bananas" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "properties" => {
                "ref" => {"type" => [{"type" => "JSONModel(:banana) uri"}]}
              }
            }
          }
        },
      },
    }')

    JSONModel.stub(:schema_src).with('banana').and_return('{
      :schema => {
        "$schema" => "http://www.archivesspace.org/archivesspace.json",
        "type" => "object",
        "uri" => "/bananas",
        "properties" => {
          "uri" => {"type" => "string", "required" => false},
          "apples" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "properties" => {
                "ref" => {"type" => [{"type" => "JSONModel(:apple) uri"}]}
              }
            }
          }
        },
      },
    }')


    class Apple < Sequel::Model(:apple)
      include ASModel
      include Relationships
      set_model_scope :global
      corresponds_to JSONModel(:apple)
    end


    class Banana < Sequel::Model(:banana)
      include ASModel
      include Relationships
      set_model_scope :global
      corresponds_to JSONModel(:banana)

      define_relationship(:name => :fruit_salad,
                          :json_property => 'apples',
                          :contains_references_to_types => proc {[Apple]})

    end


    # Need to do this in two steps because of the mutual relationship between
    # the two classes...
    class Apple < Sequel::Model(:apple)
      define_relationship(:name => :fruit_salad,
                          :json_property => 'bananas',
                          :contains_references_to_types => proc {[Banana]})
    end
  end


  it "can represent relationships with properties" do

    apple = Apple.create_from_json(JSONModel(:apple).new(:name => "granny smith"))

    banana_json = JSONModel(:banana).new(:apples => [{
                                                       :ref => apple.uri,
                                                       :sauce => "yogurt"
                                                     }])
    banana = Banana.create_from_json(banana_json)

    # Check the forwards relationship
    Banana.to_jsonmodel(banana).apples[0]['ref'].should eq(apple.uri)
    Banana.to_jsonmodel(banana).apples[0]['sauce'].should eq('yogurt')

    # And the reciprocal one
    Apple.to_jsonmodel(apple).bananas[0]['ref'].should eq(banana.uri)
    Apple.to_jsonmodel(apple).bananas[0]['sauce'].should eq('yogurt')
  end


  it "doesn't differentiate between updates made from opposing sides of the relationship" do

    apple = Apple.create_from_json(JSONModel(:apple).new(:name => "granny smith"))

    # Create a fruit salad relationship by adding an apple to a banana
    #
    # Hopefully that's the strangest thing I'll type today...
    banana_json = JSONModel(:banana).new(:apples => [{
                                                       :ref => apple.uri,
                                                       :sauce => "yogurt"
                                                     }])
    banana = Banana.create_from_json(banana_json)

    # Check the forwards relationship
    Banana.to_jsonmodel(banana).apples[0]['ref'].should eq(apple.uri)
    Banana.to_jsonmodel(banana).apples[0]['sauce'].should eq('yogurt')

    # Clear the relationship by updating the apple to remove the banana
    apple.update_from_json(JSONModel(:apple).new(:name => "granny smith",
                                                 :lock_version => 0))

    # Now the banana has no apples listed
    banana.refresh
    Banana.to_jsonmodel(banana).apples.should eq([])
  end

end
