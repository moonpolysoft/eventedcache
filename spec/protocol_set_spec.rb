require File.dirname(__FILE__) + '/spec_helper'

describe MemcacheProtocol, "in set mode" do
  before(:each) do
    @protocol = MemcacheProtocol.new
    @protocol.mode = :set
  end
  
  it "should parse a stored response" do
    @protocol.execute("STORED\r\n").should be_true
    @protocol.type.should == :stored
  end
  
  it "should parse a not_stored response" do
    @protocol.execute("NOT_STORED\r\n").should be_true
    @protocol.type.should == :not_stored
  end
  
  it "should parse an exists response" do
    @protocol.execute("EXISTS\r\n").should be_true
    @protocol.type.should == :exists
  end
  
  it "should parse a not_found response" do
    @protocol.execute("NOT_FOUND\r\n").should be_true
    @protocol.type.should == :not_found
  end
end