require 'spec_helper'

describe 'Date model' do


  it "Allows an expression date to created" do

    date = ASDate.create_from_json(JSONModel(:date).
                                 from_hash({
                                             "date_type" => "expression",
                                             "label" => "creation",
                                             "expression" => "The day before yesterday",
                                           }))

    ASDate[date[:id]].expression.should eq("The day before yesterday")
  end


  it "Throws a validation error if no expression or begin date is set" do
    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "date_type" => "single",
                                               "label" => "creation",
                                             }))
    }.should raise_error(JSONModel::ValidationException)
  end


  it "Allows a single date to created" do

    date = ASDate.create_from_json(JSONModel(:date).
                                 from_hash({
                                             "date_type" => "single",
                                             "label" => "creation",
                                             "begin" => "2012-05-14",
                                             "end" => "2012-05-14",
                                           }))

    ASDate[date[:id]].begin.should eq("2012-05-14")
  end


  it "Throws a validation error when a begin time is set but no end time is set" do

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "date_type" => "bulk",
                                               "label" => "creation",
                                               "begin" => "2012-05-14",
                                               "begin_time" => "12:00",
                                               "end" => "2012-05-14",
                                             }))
    }.should raise_error(JSONModel::ValidationException)
  end


  it "Throws a validation error when begin is not a valid ISO Date" do

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "type" => "single",
                                               "label" => "creation",
                                               "begin" => "123",
                                               "end" => "123",
                                             }))
    }.should raise_error(JSONModel::ValidationException)

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "date_type" => "single",
                                               "label" => "creation",
                                               "begin" => "2012-13",
                                               "end" => "2012-13",
                                             }))
    }.should raise_error(JSONModel::ValidationException)

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                  from_hash({
                                              "date_type" => "single",
                                              "label" => "creation",
                                              "begin" => "2012-12-32",
                                              "end" => "2012-12-32",
                                            }))
    }.should raise_error(JSONModel::ValidationException)

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                  from_hash({
                                              "date_type" => "single",
                                              "label" => "creation",
                                              "begin" => "FOOBAR",
                                              "end" => "FOOBAR",
                                            }))
    }.should raise_error(JSONModel::ValidationException)
  end


  it "Throws a validation error when begin time is not a valid ISO Date" do

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "date_type" => "single",
                                               "label" => "creation",
                                               "begin" => "2012",
                                               "end" => "2012",
                                               "begin_time" => "12",
                                               "end_time" => "12",
                                             }))
    }.should raise_error(JSONModel::ValidationException)

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "date_type" => "single",
                                               "label" => "creation",
                                               "begin" => "2012",
                                               "end" => "2012",
                                               "begin_time" => "25:00",
                                               "end_time" => "25:00",
                                             }))
    }.should raise_error(JSONModel::ValidationException)

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "date_type" => "single",
                                               "label" => "creation",
                                               "begin" => "2012",
                                               "end" => "2012",
                                               "begin_time" => "23:72",
                                               "end_time" => "23:72",
                                             }))
    }.should raise_error(JSONModel::ValidationException)

    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                   from_hash({
                                               "date_type" => "single",
                                               "label" => "creation",
                                               "begin" => "2012",
                                               "end" => "2012",
                                               "begin_time" => "23:40:61",
                                               "end_time" => "23:40:61",
                                             }))
    }.should raise_error(JSONModel::ValidationException)

    date = ASDate.create_from_json(JSONModel(:date).
                                 from_hash({
                                             "date_type" => "single",
                                             "label" => "creation",
                                             "begin" => "2012",
                                             "end" => "2012",
                                             "begin_time" => "23:40:40",
                                             "end_time" => "03:01:00",
                                           }))
    ASDate[date[:id]].begin_time.should eq("23:40:40")
    ASDate[date[:id]].end_time.should eq("03:01:00")
  end


  it "creates a bulk date with begin and end times" do
    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                     from_hash({
                                               "date_type" => "bulk",
                                               "label" => "creation",
                                               "begin" => "2001-01-01",
                                               "end" => "2009-12-31",
                                               "begin_time" => "00:00:00",
                                               "end_time" => "23:59:59",
                                               }))
    }.should_not raise_error
  end


  it "reports an error if a bulk date lacks a begin date" do
    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                     from_hash({
                                               "date_type" => "bulk",
                                               "label" => "creation",
                                               "end" => "2009-12-31",
                                               }))
    }.should raise_error(JSONModel::ValidationException)
  end


  it "reports an error if a bulk date lacks an end date" do
    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                     from_hash({
                                               "date_type" => "bulk",
                                               "label" => "creation",
                                               "begin" => "2001-01-01",
                                               }))
    }.should raise_error(JSONModel::ValidationException)
  end


  it "reports an error if a bulk date has a begin time and lacks an end time" do
    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                     from_hash({
                                               "date_type" => "bulk",
                                               "label" => "creation",
                                               "begin" => "2001-01-01",
                                               "end" => "2009-12-31",
                                               "begin_time" => "00:00",
                                               }))
    }.should raise_error(JSONModel::ValidationException)
  end


  it "reports an error if a bulk date has an end time and lacks a begin time" do
    expect {
      date = ASDate.create_from_json(JSONModel(:date).
                                     from_hash({
                                               "date_type" => "bulk",
                                               "label" => "creation",
                                               "begin" => "2001-01-01",
                                               "end" => "2009-12-31",
                                               "end_time" => "23:59:59",
                                               }))
    }.should raise_error(JSONModel::ValidationException)
  end

end
