require "net/http"
require "json"
require "selenium-webdriver"
require "digest"
require "rspec"
require 'rubygems'
require_relative '../../common/test_utils'
require_relative '../../config/config-distribution'

$sleep_time = 0.0

$backend_port = TestUtils::free_port_from(3636)
$frontend_port = TestUtils::free_port_from(4545)
$backend = "http://localhost:#{$backend_port}"
$frontend = "http://localhost:#{$frontend_port}"
$expire = 300

class RSpec::Core::Example
  def passed?
    @exception.nil?
  end

  def failed?
    !passed?
  end
end


module Selenium
  module WebDriver
    module Firefox
      class Binary

        # Searching the registry causes a EXCEPTION_ACCESS_VIOLATION under
        # Windows 7.  Skip this step and just look for Firefox in the usual
        # places.
        def self.windows_registry_path
          nil
        end
      end
    end
  end

  module Config
    def self.retries
      100
    end
  end

end


class Selenium::WebDriver::Driver
  def wait_for_ajax
    try = 0
    while (self.execute_script("return document.readyState") != "complete" or
           not self.execute_script("return window.$ == undefined || $.active == 0"))
      if (try > Selenium::Config.retries)
        raise "Retry limit hit on wait_for_ajax"
      end

      sleep(0.1)
      try += 1
    end
  end

  alias :find_element_orig :find_element
  def find_element(*selectors)
    wait_for_ajax

    try = 0
    while true
      begin
        elt = find_element_orig(*selectors)

        if not elt.displayed?
          raise Selenium::WebDriver::Error::NoSuchElementError.new("Not visible (yet?)")
        end

        return elt
      rescue Selenium::WebDriver::Error::NoSuchElementError => e
        if try < Selenium::Config.retries
          try += 1
          $sleep_time += 0.1
          sleep 0.1
          puts "find_element: #{try} misses on selector '#{selectors}'.  Retrying..." if (try % 5) == 0
        else
          puts "Failed to find #{selectors}"

          raise e
        end
      end
    end
  end


  def blocking_find_elements(*selectors)
    # Hit with find_element first to invoke our usual retry logic
    find_element(*selectors)

    find_elements(*selectors)
  end


  def ensure_no_such_element(*selectors)
    wait_for_ajax

    begin
      find_element_orig(*selectors)
      raise "Element was supposed to be absent: #{selectors}"
    rescue Selenium::WebDriver::Error::NoSuchElementError => e
      return true
    end
  end


  def click_and_wait_until_gone(*selector)
    element = self.find_element(*selector)
    element.click

    begin
      try = 0
      while self.find_element_orig(*selector).equal? element
        if try < Selenium::Config.retries
          try += 1
          $sleep_time += 0.1
          sleep 0.1
          puts "click_and_wait_until_gone: #{try} hits selector '#{selector}'.  Retrying..." if (try % 5) == 0
        else
          raise Selenium::WebDriver::Error::NoSuchElementError.new(selector.inspect)
        end
      end
    rescue Selenium::WebDriver::Error::NoSuchElementError
      nil
    end
  end


  def complete_4part_id(pattern)
    # Was 4, but now that the input boxes are disabled this wasn't filling out the last 3.
    accession_id = Digest::MD5.hexdigest("#{Time.now}#{$$}").scan(/.{6}/)[0...1]
    accession_id.each_with_index do |elt, i|
      self.clear_and_send_keys([:id, sprintf(pattern, i)], elt)
    end
  end


  def find_element_with_text(xpath, pattern, noError = false, noRetry = false)
    self.find_element(:tag_name => "body").find_element_with_text(xpath, pattern, noError, noRetry)
  end


  def clear_and_send_keys(selector, keys)
    Selenium::Config.retries.times do
      begin
        elt = self.find_element(*selector)
        elt.clear
        elt.send_keys(keys)
        break
      rescue
        $sleep_time += 0.1
        sleep 0.1
      end
    end
  end


end


class Selenium::WebDriver::Element

  def select_option(value)
    self.find_elements(:tag_name => "option").each do |option|
      if option.attribute("value") === value
        option.click
        return
      end
    end

    raise "Couldn't select value: #{value}"
  end


  def get_select_value
    self.find_elements(:tag_name => "option").each do |option|
      return option.attribute("value") if option.attribute("checked")
    end

    return ""
  end

  def nearest_ancestor(xpath)
    self.find_element(:xpath => './ancestor-or-self::' + xpath + '[1]')
  end


  def containing_subform
    nearest_ancestor('div[contains(@class, "subrecord-form-fields")]')
  end


  def find_element_with_text(xpath, pattern, noError = false, noRetry = false)
    Selenium::Config.retries.times do |try|

      matches = self.find_elements(:xpath => xpath)
      begin
        matches.each do | match |
          return match if match.text =~ pattern
        end
      rescue
        # Ignore exceptions and retry
      end

      if noRetry
        return nil
      end

      $sleep_time += 0.1
      sleep 0.1
      puts "find_element_with_text: #{try} misses on selector ':xpath => #{xpath}'.  Retrying..." if (try % 10) == 0
    end

    return nil if noError
    raise Selenium::WebDriver::Error::NoSuchElementError.new("Could not find element for xpath: #{xpath} pattern: #{pattern}")
  end

end



def login(user, pass)
  $driver.navigate.to $frontend

  $driver.find_element(:link, "Sign In").click
  $driver.clear_and_send_keys([:id, 'user_username'], user)
  $driver.clear_and_send_keys([:id, 'user_password'], pass)
  $driver.find_element(:id, 'login').click
end


def logout
  ## Complete the logout process
  user_menu = $driver.find_elements(:css, '.user-container .dropdown-menu.pull-right').first
  if !user_menu || !user_menu.displayed?
    $driver.find_element(:css, 'body').find_element(:css, '.user-container .btn')
    $driver.find_element(:css, 'body').find_element(:css, '.user-container .btn').click
  end

  $driver.find_element(:link, "Logout").click
  $driver.find_element(:link, "Sign In")
end


RSpec.configure do |c|
  c.fail_fast = true
end


def cleanup
  $driver.quit if $driver

  if ENV["COVERAGE_REPORTS"] == 'true'
    begin
      TestUtils::get(URI("#{$frontend}/test/shutdown"))
    rescue
      # Expected to throw an error here, but that's fine.
    end
  else
    TestUtils::kill($frontend_pid) if $frontend_pid
  end

  TestUtils::kill($backend_pid) if $backend_pid
end



def selenium_init
  standalone = true

  if ENV["ASPACE_BACKEND_URL"] and ENV["ASPACE_FRONTEND_URL"]
    $backend = ENV["ASPACE_BACKEND_URL"]
    $frontend = ENV["ASPACE_FRONTEND_URL"]
    standalone = false
  end

  AppConfig[:backend_url] = $backend

  (@backend, @frontend) = [false, false]
  if standalone
    puts "Starting backend and frontend using #{$backend} and #{$frontend}"
    $backend_pid = TestUtils::start_backend($backend_port,
                                            {
                                              :frontend_url => $frontend,
                                              :session_expire_after_seconds => $expire
                                            })
    $frontend_pid = TestUtils::start_frontend($frontend_port, $backend)
  end

  @user = "testuser#{Time.now.to_i}_#{$$}"

  if ENV['TRAVIS']
    caps = Selenium::WebDriver::Remote::Capabilities.firefox
    caps[:name] = ENV['TEST_NAME'] || "All tests"
    caps["selenium-version"] = "2.28.0"
    caps.platform = 'Linux'
    caps.version = '16'
    puts "travis-ci/saucelabs integration"
    $driver = Selenium::WebDriver.for(
      :remote,
      :url => "http://" + ENV['SAUCE_USERNAME'] + ":" + ENV['SAUCE_ACCESS_KEY']+ "@ondemand.saucelabs.com:80/wd/hub",
      :desired_capabilities => caps)
  else
    $driver = Selenium::WebDriver.for :firefox
  end


  $driver.manage.window.maximize
end


def assert(&block)
  try = 0

  begin
    block.call
  rescue
    try += 1
    if try < Selenium::Config.retries
      $sleep_time += 0.1
      sleep 0.1
      retry
    else
      puts "Assert giving up"
      raise $!
    end
  end
end


def admin_backend_request(req)
  res = Net::HTTP.post_form(URI("#{$backend}/users/admin/login"), :password => "admin")
  admin_session = JSON(res.body)["session"]

  req["X-ARCHIVESSPACE-SESSION"] = admin_session

  uri = URI("#{$backend}")

  Net::HTTP.start(uri.hostname, uri.port) do |http|
    res = http.request(req)

    if res.code != "200"
      raise "Bad response: #{res.body}"
    end

    res
  end
end


def create_test_repo(code, description, wait = true)
  create_repo = URI("#{$backend}/repositories")

  req = Net::HTTP::Post.new(create_repo.path)
  req.body = "{\"repo_code\": \"#{code}\", \"description\": \"#{description}\"}"

  response = admin_backend_request(req)
  repo_uri = JSON.parse(response.body)['uri']


  # Give the webhook time to fire
  sleep 5 if wait

  [code, repo_uri]
end


def create_user
  user = "user_#{Time.now.to_i}_#{$$}"
  pass = "pass_#{Time.now.to_i}_#{$$}"

  req = Net::HTTP::Post.new("/users?password=#{pass}")
  req.body = "{\"username\": \"#{user}\", \"name\": \"#{user}\"}"

  admin_backend_request(req)

  [user, pass]
end


def select_repo(code)
  $driver.find_element(:css, '.user-container .btn').click
  $driver.find_element(:id, 'select_repo').click

  if not $driver.find_element_with_text('//span', /#{code}/, true, true)
    # Select it
    $driver.find_element(:link_text => code).click
  else
    $driver.find_element(:css, '.user-container .btn').click
  end
end


def add_user_to_managers(user, repo)
  req = Net::HTTP::Get.new("#{repo}/groups?page=1")

  groups = admin_backend_request(req)

  uri = JSON.parse(groups.body)['results'].find {|group| group['group_code'] == 'repository-archivists'}['uri']

  req = Net::HTTP::Get.new(uri)
  group = JSON.parse(admin_backend_request(req).body)
  group['member_usernames'] = [user]

  req = Net::HTTP::Post.new(uri)
  req.body = group.to_json

  admin_backend_request(req)
end


def create_accession(title)
  req = Net::HTTP::Post.new("#{$test_repo_uri}/accessions")
  req.body = {:title => title, :id_0 => "#{Time.now.to_i}#{$$}", :accession_date => "2000-01-01"}.to_json

  response = admin_backend_request(req)

  raise response.body if response.code != '200'

  title
end


def create_agent(name)
  req = Net::HTTP::Post.new("/agents/people")
  req.body = {
    "agent_contacts" => [],
    "agent_type" => "agent_person",
    "names" => [
              {
                "name_order" => "inverted",
                "authority_id" => "authid123",
                "primary_name" => name,
                "rest_of_name" => name,
                "sort_name" => name,
                "source" => "local"
              }
             ],
  }.to_json


  response = admin_backend_request(req)

  raise response.body if response.code != '200'

  name
end


# A few globals here to allow things to be re-used between nested suites.
def login_as_archivist
  if !$test_repo
    ($test_repo, $test_repo_uri) = create_test_repo("repo_#{Time.now.to_i}_#{$$}", "description")
  end

  if !$archivist_user
    ($archivist_user, $archivist_pass) = create_user
    add_user_to_managers($archivist_user, $test_repo_uri)
  end


  login($archivist_user, $archivist_pass)

  select_repo($test_repo)
end


def report_sleep
  puts "Total time spent sleeping: #{$sleep_time.inspect} seconds"
end


def check_sort_name_eq(id, value)
  $driver.execute_script("$('##{id.gsub('sort_name', 'primary_name')}').trigger('change');")

  $driver.wait_for_ajax

  assert do
    elt = $driver.find_element(:id => id).attribute("value")

    if !elt || elt.empty?
      raise "Retrying"
    else
      elt.should eq(value)
    end
  end
end
