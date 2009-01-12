require File.dirname(__FILE__) + '/spec_helper'

describe MemcacheProtocol, "in stats mode" do
  before(:each) do
    @protocol = MemcacheProtocol.new
    @protocol.mode = :stats
  end
  
  it "should parse simple general stats" do
    stats = {"pid" => "1234567"}
    @protocol.execute("STAT pid 1234567\r\nEND\r\n").should be_true
    @protocol.stats.should == stats
  end
  
  it "should parse string stats" do
    stats = {"blah" => "fuck"}
    @protocol.execute("STAT blah fuck\r\nEND\r\n").should be_true
    @protocol.stats.should == stats
  end
  
  it "should parse complicated stats" do
    stats = {"pid" => "1234567", "blah" => "fuck", "blarg" => "1fuck"}
    @protocol.execute("STAT pid 1234567\r\nSTAT blah fuck\r\nSTAT blarg 1fuck\r\nEND\r\n").should be_true
    @protocol.stats.should == stats
  end
  
  it "should parse stats that don't have the STAT header" do
    stats = {"64" => "1", "128" => "1"}
    @protocol.execute("64 1\r\n128 1\r\nEND\r\n").should be_true
    @protocol.stats.should == stats
  end
end