require 'tmpdir'
require 'java'

class AppConfig
  @@parameters = {}

  def self.[](parameter)
    if !@@parameters.has_key?(parameter)
      raise "No value set for config parameter: #{parameter}"
    end

    val = @@parameters[parameter]

    val.respond_to?(:call) ? val.call : val
  end


  def self.[]=(parameter, value)
    @@parameters[parameter] = value
  end


  def self.load_overrides_from_properties
    # Override defaults from the command-line if specified
    java.lang.System.get_properties.each do |property, value|
      if property =~ /aspace.config.(.*)/
        @@parameters[$1.intern] = value
      end
    end
  end


  def self.load_into(obj)
    @@parameters.each do |config, value|
      obj.send(:"#{config}=", value)
    end
  end


  def self.get_preferred_config_path

    if java.lang.System.getProperty("aspace.config")
      # Explicit Java property
      java.lang.System.getProperty("aspace.config")
    elsif java.lang.System.getProperty("catalina.home")
      # Tomcat users
      File.join(java.lang.System.getProperty("catalina.home"), "conf", "config.rb")
    elsif __FILE__.index(java.lang.System.getProperty("java.io.tmpdir")) != 0
      File.join(File.dirname(__FILE__), "config.rb")
    else
      File.join(Dir.home, ".aspace_config.rb")
    end

  end

  def self.find_user_config
    possible_locations = [
                          get_preferred_config_path,
                          File.join(File.dirname(__FILE__), "config.rb"),
                         ]

    possible_locations.each do |config|
      if config and File.exists?(config)
        return config
      end
    end

    nil
  end


  def self.load_user_config
    config = find_user_config

    if config
      puts "Loading ArchivesSpace configuration file from path: #{config}"
      load config
    end

    self.load_overrides_from_properties
  end


  def self.demo_db_url
    "jdbc:derby:#{File.join(AppConfig[:data_directory], "archivesspace_demo_db")};create=true;aspacedemo=true"
  end


  def self.load_defaults
    AppConfig[:data_directory] = File.join(Dir.home, "ArchivesSpace")
    AppConfig[:backup_directory] = proc { File.join(AppConfig[:data_directory], "demo_db_backups") }
    AppConfig[:solr_index_directory] = proc { File.join(AppConfig[:data_directory], "solr_index") }
    AppConfig[:solr_home_directory] = proc { File.join(AppConfig[:data_directory], "solr_home") }
    AppConfig[:solr_indexing_frequency_seconds] = 30

    AppConfig[:max_page_size] = 250

    AppConfig[:db_url] = proc { AppConfig.demo_db_url }
    AppConfig[:db_max_connections] = 10

    AppConfig[:allow_unsupported_database] = false

    AppConfig[:demo_db_backup_schedule] = "0 4 * * *"
    AppConfig[:demo_db_backup_number_to_keep] = 7

    AppConfig[:backend_url] = "http://localhost:4567"
    AppConfig[:frontend_url] = "http://localhost:3000"
    AppConfig[:solr_url] = "http://localhost:2999"

    AppConfig[:frontend_theme] = "default"

    AppConfig[:session_expire_after_seconds] = 3600

    AppConfig[:search_username] = "search_indexer"
  end


  def self.reload
    @@parameters = {}

    AppConfig.load_defaults
    AppConfig.load_user_config
  end

end


## Application defaults
##
## Don't change these here: if you want to set them, copy config-example.rb to
## config.rb and override them in that file instead.

AppConfig.reload
