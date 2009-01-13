require File.dirname(__FILE__) + '/../spec_helper'

#this ensures we act similarly to EM by calling initialize on the module code
class FakeEmConn
  include Connection
  
  def initialize(*args)
    super
  end
end

describe Connection, "with set requests" do
  before(:each) do
    @conn = FakeEmConn.new
  end
  
  it "should handle set requests with a callback" do
    called_back = false
    @conn.should_receive(:send_data).with("set blah 0 0 4\r\nfuck\r\n")
    @conn.set_command("set", "blah", "fuck") do |response|
      called_back = true
      response.should == :stored
    end
    @conn.receive_data("STORED\r\n")
    called_back.should be_true
  end
  
  it "should handle set requests without a callback" do
    @conn.should_receive(:send_data).with("set blah 0 0 4 noreply\r\nfuck\r\n")
    @conn.set_command("set", "blah", "fuck")
  end
  
  it "should handle set request options" do
    @conn.should_receive(:send_data).with("set blah 4 12345 4 noreply\r\nfuck\r\n")
    @conn.set_command("set", "blah", "fuck", {:flags => 4, :expiry => 12345})
  end
  
  it "should handle cas operations" do
    @conn.should_receive(:send_data).with("cas blah 4 12345 4 1 noreply\r\nfuck\r\n")
    @conn.set_command("cas", "blah", "fuck", {:flags => 4, :expiry => 12345, :cas => 1})
  end
  
end

describe Connection, "with inc/dec requests" do
  before(:each) do
    @conn = FakeEmConn.new
  end
  
  it "should send an increment command and yield a value" do
    @conn.should_receive(:send_data).with("inc blah 3\r\n")
    callback = false
    @conn.inc("blah", 3) do |value|
      callback = true
      value.should == 4
    end
    @conn.receive_data("4\r\n")
    callback.should be_true
  end
  
  it "should send a decrement command and yield a value" do
    @conn.should_receive(:send_data).with("dec blah 3\r\n")
    callback = false
    @conn.dec("blah", 3) do |value|
      callback = true
      value.should == 4
    end
    @conn.receive_data("4\r\n")
    callback.should be_true
  end
end

describe Connection, "with get/gets requests" do
  before(:each) do
    @conn = FakeEmConn.new
  end
  
  it "should return nil for a cache miss" do
    @conn.should_receive(:send_data).with("get blah\r\n")
    callback = false
    @conn.get("blah") do |value|
      callback = true
      value.should be_nil
    end
    @conn.receive_data("END\r\n")
    callback.should be_true
  end
  
  it "should do a simple single get" do
    @conn.should_receive(:send_data).with("get blah\r\n")
    callback = false
    @conn.get("blah") do |value|
      callback = true
      value.data.should == "fucku"
    end
    @conn.receive_data("VALUE blah 0 5\r\nfucku\r\nEND\r\n")
    callback.should be_true
  end
  
  it "should do a complicated multiget" do
    @conn.should_receive(:send_data).with("get blah fuck\r\n")
    callback = false
    @conn.get("blah", "fuck") do |values|
      callback = true
      values.length.should == 2
    end
    @conn.receive_data("VALUE blah 0 5\r\nfucku\r\nVALUE blaa 0 5\r\nfucka\r\nEND\r\n")
    callback.should be_true
  end
  
  it "should do a gets" do
    @conn.should_receive(:send_data).with("gets blah fuck\r\n")
    callback = false
    @conn.gets("blah", "fuck") do |values|
      callback = true
      values.length.should == 2
    end
    @conn.receive_data("VALUE blah 0 5 1\r\nfucku\r\nVALUE blaa 0 5 2\r\nfucka\r\nEND\r\n")
    callback.should be_true
  end
end