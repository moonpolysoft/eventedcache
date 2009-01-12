require File.dirname(__FILE__) + '/spec_helper'

describe MemcacheProtocol, "with other crap" do
  before(:each) do
    @protocol = MemcacheProtocol.new
  end
  
  it "should parse the ok response from flush_all" do
    @protocol.mode = :flush_all
    @protocol.execute("OK\r\n").should be_true
    @protocol.type.should == :ok
  end
  
  it "should parse the version response from version" do
    @protocol.mode = :version
    @protocol.execute("VERSION 1.2.3\r\n").should be_true
    @protocol.type.should == :version
    @protocol.version.should == "1.2.3"
  end
end