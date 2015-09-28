require 'spec_helper'

describe Pingdom::Client do
  let(:client){ Pingdom::Client.new(CREDENTIALS.merge(:logger => LOGGER)) }
    
  describe "#test!" do
    
    it "should test a single endpoint" do
      response = client.test!(:host => "pingdom.com", :type => "http")
      
      response.status.should == "up"
      response.responsetime.should be_a(Numeric)
    end
    
  end
  
  describe "#checks" do
    
    it "should get a list of checks" do
      checks = client.checks
      
      first = checks.first
      first.should be_a(Pingdom::Check)
      first.created.should be_a(Numeric)
    end
    
    let(:new_check) {client.create_check({name: "Gizoogle", type: "http", host: "google.com", encryption: "true"})}
    it "should be able to create a check and delete that check" do
      new_check.should be_a(Pingdom::Check)
      new_check.id.should_not be_nil
    end
    
    it "should be able to pause a check" do
      response = new_check.pause
      response.body["message"].should == "Modification of check was successful!"
    end
    
    it "should be able to delete a check" do
      response = new_check.delete
      response.body["message"].should == "Deletion of check was successful!"
    end
    
  end
  
  describe "#limit" do
    { :short  => "short term",
      :long   => "long term" }.each do |(key, label)|
      describe label do
        let(:limit){ client.test!(:host => "pingdom.com", :type => "http"); client.limit[key] }
        
        it "should indicate how many requests can be made" do
          limit[:remaining].should be_a(Numeric)
        end
        
        it "should indicate when the current limit will be reset" do
          limit[:resets_at].acts_like?(:time).should be_true
        end
      end
    end
  end
  
end
