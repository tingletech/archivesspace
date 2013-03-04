require 'spec_helper'

describe "Enumeration controller" do

  before(:each) do
    enum = $testdb[:enumeration].filter(:name => 'test_enum')
    if enum.count > 0
      $testdb[:enumeration_value].filter(:enumeration_id => enum.first[:id]).delete
      enum.delete
    end

    @enum_id = JSONModel(:enumeration).from_hash(:name => "test_enum",
                                                 :values => ["abc", "def"]).save

    if !$testdb.table_exists?(:controller_enum_model)
      $testdb.create_table(:controller_enum_model) do
        primary_key :id
        Integer :my_enum_id
        Integer :lock_version, :default => 0
        DateTime :create_time
        DateTime :last_modified
      end

      $testdb.alter_table(:controller_enum_model) do
        add_foreign_key([:my_enum_id], :enumeration_value, :key => :id)
      end
    end

    @model = Class.new(Sequel::Model(:controller_enum_model)) do
      include ASModel
      include DynamicEnums

      set_model_scope :global

      uses_enums(:property => 'my_enum', :uses_enum => 'test_enum')
    end
  end



  it "can return all defined enumerations" do
    JSONModel(:enumeration).all.find {|obj| obj.name == 'test_enum'}.values.count.should eq(2)
  end


  it "can return a single enumeration by ID" do
    enum = JSONModel(:enumeration).all.find {|obj| obj.name == 'test_enum'}
    JSONModel(:enumeration).find(enum.id).values.count.should eq(2)
  end


  it "can add and remove values (if the value isn't used)" do
    obj = JSONModel(:enumeration).find(@enum_id)
    obj.values += ["unused"]
    obj.save

    obj.values -= ["unused"]
    obj.save

    JSONModel(:enumeration).find(@enum_id).values.count.should eq(2)
  end


  it "can't remove values that are being used" do
    obj = JSONModel(:enumeration).find(@enum_id)
    obj.values += ["new_value"]
    obj.save

    value = EnumerationValue[:value => 'new_value']
    record = @model.create(:my_enum_id => value.id)

    obj.values -= ['new_value']

    expect {
      obj.save
    }.to raise_error(ConflictException)
  end


  it "can migrate a value to get rid of it" do
    obj = JSONModel(:enumeration).find(@enum_id)
    obj.values += ["new_value"]
    obj.save

    value = EnumerationValue[:value => 'new_value']
    record = @model.create(:my_enum_id => value.id)

    old_time = record[:last_modified]

    request = JSONModel(:enumeration_migration).from_hash(:enum_uri => obj.uri,
                                                          :from => 'new_value',
                                                          :to => 'abc')
    request.save

    record.refresh
    record[:last_modified].should_not eq(old_time)
    record[:my_enum_id].should_not eq(value.id)
  end

end
