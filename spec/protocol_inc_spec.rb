require File.dirname(__FILE__) + '/spec_helper'

describe MemcacheProtocol, "in inc mode" do
  before(:each) do
    @protocol = MemcacheProtocol.new
    @protocol.mode = :inc
  end
  
  it "should parse a not_found response" do
    @protocol.execute("NOT_FOUND\r\n").should be_true
    @protocol.type.should == :not_found
  end
  
  it "should parse an inc value response" do
    @protocol.execute("12345667\r\n").should be_true
    @protocol.type.should == :inc_value
    @protocol.inc_value.should == 12345667
  end
end