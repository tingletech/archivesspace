require 'rubygems'
require 'sequel'

require_relative 'exceptions'
require_relative 'logging'
require_relative "../../../config/config-distribution"
require_relative "../../../common/jsonmodel"
require_relative "../model/db_migrator"

JSONModel::init



if ENV["ASPACE_INTEGRATION"] == "true"
  AppConfig[:db_url] = "jdbc:derby:memory:integrationdb;create=true;aspacedemo=true"
end

if not Thread.current[:test_mode]
  if AppConfig[:db_url] =~ /aspacedemo=true/
    puts "Running database migrations for demo database"

    Sequel.connect(AppConfig[:db_url]) do |db|
      DBMigrator.setup_database(db)
    end

    puts "All done."
  end
end
