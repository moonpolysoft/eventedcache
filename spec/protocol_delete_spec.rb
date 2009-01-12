require File.dirname(__FILE__) + '/spec_helper'

describe MemcacheProtocol, "in delete mode" do
  before(:each) do
    @protocol = MemcacheProtocol.new
    @protocol.mode = :delete
  end
  
  it "should parse a deleted response" do
    @protocol.execute("DELETED\r\n").should be_true
    @protocol.type.should == :deleted
  end
  
  it "should parse a not_found response" do
    @protocol.execute("NOT_FOUND\r\n").should be_true
    @protocol.type.should == :not_found
  end
end