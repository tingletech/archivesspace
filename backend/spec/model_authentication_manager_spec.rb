require 'spec_helper'

class MockAuthenticationSource

  def initialize(opts)
    @opts = opts
  end

  def authenticate(username, pass)
    raise "Boom" if @opts[:blowup]

    user = @opts[:users][username]

    if (user && user[:password] == pass)
      JSONModel(:user).from_hash(:username => username, :name => "Mark")
    end
  end

  def name
    "MockAuthenticationSource"
  end

end


describe 'Authentication manager' do

  let(:auth_source) do
    {
      :model => 'MockAuthenticationSource',
      :users => {
        'hello' => {:password => 'world'}
      }
    }
  end


  context "Authentication" do
    before(:each) do
      AppConfig[:authentication_sources] = [auth_source]
    end


    it "successfully logs in to a custom provider" do
      AuthenticationManager.authenticate("hello", "world").should_not eq(nil)
    end


    it "handles failed logins against a custom provider" do
      AuthenticationManager.authenticate("hello", "wrongpass").should eq(nil)
    end


    it "handles lots of simultaneous logins for the same user with grace" do
      threads = (0...4).map do
        Thread.new do
          50.times.map { AuthenticationManager.authenticate("hello", "world") }
        end
      end

      threads.map(&:value).flatten.find_all(&:nil?).count.should eq(0)
    end

  end


  context "Error handling" do

    it "ignores errors thrown by any single provider" do
      AppConfig[:authentication_sources] = [
                                             {
                                               :model => 'MockAuthenticationSource',
                                               :blowup => true,
                                             },
                                            auth_source
                                            ]

      # Still fine
      AuthenticationManager.authenticate("hello", "world").should_not eq(nil)
    end
  end
end
