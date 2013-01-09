#!/usr/bin/env ruby

require 'rubygems'
require 'tmpdir'
require 'tempfile'
require 'json'
require 'net/http'
require_relative '../../common/test_utils'
require_relative '../../indexer/periodic_indexer.rb'
require 'ladle'

Dir.chdir(File.dirname(__FILE__))
$solr_port = 2999
$ldap_port = 3897
$port = 3434
$url = "http://localhost:#{$port}"
$me = Time.now.to_i
$expire = 3

def url(uri)
  URI("#{$url}#{uri}")
end


def do_post(s, url)
  Net::HTTP.start(url.host, url.port) do |http|
    req = Net::HTTP::Post.new(url.request_uri)
    req.body = s
    req["X-ARCHIVESSPACE-SESSION"] = @session if @session

    r = http.request(req)

    {:body => JSON(r.body), :status => r.code}
  end
end


def do_get(url)
  Net::HTTP.start(url.host, url.port) do |http|
    req = Net::HTTP::Get.new(url.request_uri)
    req["X-ARCHIVESSPACE-SESSION"] = @session if @session
    r = http.request(req)

    {:body => JSON(r.body), :status => r.code}
  end
end



def fail(msg, response)
  raise "FAILURE: #{msg} (#{response.inspect})"
end


def start_ldap
  Ladle::Server.new(:tmpdir => Dir.tmpdir,
                    :port   => $ldap_port,
                    :ldif   => File.absolute_path("data/aspace.ldif"),
                    :domain => "dc=archivesspace,dc=org").tap do |s|
    s.start
  end
end



def run_tests(opts)

  puts "Create an admin session"
  r = do_post(URI.encode_www_form(:password => "admin"),
              url("/users/admin/login?expiring=false"))

  @session = r[:body]["session"] or fail("Admin login", r)

  puts "Create a repository"
  r = do_post({
                :repo_code => "test#{$me}",
                :description => "integration test repository #{$$}"
              }.to_json,
              url("/repositories"))

  repo_id = r[:body]["id"] or fail("Repository creation", r)


  puts "Create a second repository"
  r = do_post({
                :repo_code => "another#{$me}",
                :description => "another integration test repository #{$$}"
              }.to_json,
              url("/repositories"))

  second_repo_id = r[:body]["id"] or fail("Second repository creation", r)


  puts "Create an accession"
  r = do_post({
                :id_0 => "test#{$me}",
                :title => "integration test accession #{$$}",
                :accession_date => "2011-01-01"
              }.to_json,
              url("/repositories/#{repo_id}/accessions"));

  acc_id = r[:body]["id"] or fail("Accession creation", r)


  puts "Request the accession"
  r = do_get(url("/repositories/#{repo_id}/accessions/#{acc_id}"));

  r[:body]["title"] =~ /integration test accession/ or
    fail("Accession fetch", r)



  puts "Create an accession in the second repository"
  r = do_post({
                :id_0 => "another#{$me}",
                :title => "ANOTHER integration test accession #{$$}",
                :accession_date => "2011-01-01"
              }.to_json,
              url("/repositories/#{second_repo_id}/accessions"));

  r[:body]["id"] or fail("Second accession creation", r)


  puts "Create a subject with no terms"
  r = do_post({
                :terms => [],
                :vocabulary => "/vocabularies/1"
              }.to_json,
              url("/subjects"))
  r[:status] === "400" or fail("Invalid subject check", r)


  puts "Create a subject"
  r = do_post({
                :terms => [
                           :term => "Some term #{$me}",
                           :term_type => "Function",
                           :vocabulary => "/vocabularies/1"
                          ],
                :vocabulary => "/vocabularies/1"
              }.to_json,
              url("/subjects"))

  subject_id = r[:body]["id"] or fail("Subject creation", r)


  puts "Create a resource"
  r = do_post({
                :title => "integration test resource #{$$}",
                :id_0 => "abc123",
                :subjects => ["/subjects/#{subject_id}"],
                :language => "eng",
                :level => "collection",
                :extents => [{"portion" => "whole", "number" => "5 or so", "extent_type" => "reels"}]
              }.to_json,
              url("/repositories/#{repo_id}/resources"))

  coll_id = r[:body]["id"] or fail("Resource creation", r)


  puts "Retrieve the resource with subjects resolved"
  r = do_get(url("/repositories/#{repo_id}/resources/#{coll_id}?resolve[]=subjects"))
  r[:body]["resolved"]["subjects"][0]["terms"][0]["term"] == "Some term #{$me}" or
    fail("Resource fetch", r)


  puts "Create an archival object"
  r = do_post({
                :ref_id => "test#{$me}",
                :title => "integration test archival object #{$$}",
                :subjects => ["/subjects/#{subject_id}"],
                :level => "item"
              }.to_json,
              url("/repositories/#{repo_id}/archival_objects"))

  ao_id = r[:body]["id"] or fail("Archival Object creation", r)


  puts "Retrieve the archival object with subjects resolved"
  r = do_get(url("/repositories/#{repo_id}/archival_objects/#{ao_id}?resolve[]=subjects"))
  r[:body]["resolved"]["subjects"][0]["terms"][0]["term"] == "Some term #{$me}" or
    fail("Archival object fetch", r)


  if opts[:check_ldap]
    puts "Check LDAP authentication"

    r = do_post(URI.encode_www_form(:password => "wrongpassword"),
                url("/users/marktriggs/login"))

    (r[:status] == '403') or fail("LDAP login with incorrect password", r)


    r = do_post(URI.encode_www_form(:password => "testuser"),
                url("/users/marktriggs/login"))

    r[:body]["session"] or fail("LDAP login with correct password", r)


    r = do_get(url(r[:body]["user"]["uri"]))
    (r[:body]['name'] == 'Mark Triggs') or fail("User attributes from LDAP", r)
  end


  puts "Check that search indexing works"
  state = Object.new
  def state.set_last_mtime(*args); end
  def state.get_last_mtime(*args); 0; end

  AppConfig[:backend_url] = $url
  indexer = PeriodicIndexer.get_indexer(state)
  indexer.run_index_round

  r = do_get(url("/repositories/#{repo_id}/search?q=integration+test+accession+#{$$}&page=1"))
  begin
    (Integer(r[:body]['total_hits']) > 0) or fail("Search indexing", r)
  rescue TypeError
    puts "Response: #{r.inspect}"
  end


  puts "Check that search results are repository-scoped"
  # This accession was created in repository #2, so shouldn't be found
  r = do_get(url("/repositories/#{repo_id}/search?q=%22ANOTHER+integration+test+accession+#{$$}%22&page=1"))
  begin
    (Integer(r[:body]['total_hits']) == 0) or fail("Repository scoping", r)
  rescue TypeError
    puts "Response: #{r.inspect}"
  end

  puts "Create an expiring admin session"
  r = do_post(URI.encode_www_form(:password => "admin"),
              url("/users/admin/login"))

  @session = r[:body]["session"] or fail("Admin login", r)

  puts "Expire session after a nap"
  sleep $expire + 1
  r = do_get(url("/repositories"))
  r[:body]["code"] == "SESSION_EXPIRED" or fail("Session expiry", r)

end


def main

  standalone = true

  if ENV["ASPACE_BACKEND_URL"]
    $url = ENV["ASPACE_BACKEND_URL"]
    standalone = false
  end

  server = nil
  ldap = nil

  if standalone
    # start the backend
    ldap = start_ldap

    # Configure LDAP auth
    config = Tempfile.new('aspace_integration_config')
    config.write <<EOF

AppConfig[:authentication_sources] = [
                                      {
                                        :model => 'LDAPAuth',
                                        :hostname => 'localhost',
                                        :port => 3897,
                                        :base_dn => 'ou=people,dc=archivesspace,dc=org',
                                        :username_attribute => 'uid',
                                        :attribute_map => {:cn => :name}
                                      }
                                     ]

EOF
    config.close

    server = TestUtils::start_backend($port,
                                      {:session_expire_after_seconds => $expire},
                                      config.path)

    TestUtils::wait_for_url("http://localhost:#{$solr_port}/")
  end

  status = 0
  begin
    run_tests(:check_ldap => ldap)
    puts "ALL OK"
  rescue
    puts "TEST FAILED: #{$!}"
    puts $@.join("\n")
    status = 1
  end

  if server
    ldap.stop
    TestUtils::kill(server)
  end

  exit(status)
end


main
