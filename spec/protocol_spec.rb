require File.dirname(__FILE__) + '/spec_helper'

describe MemcacheProtocol do
  before(:each) do
    @protocol = MemcacheProtocol.new
  end
  
  it "should parse the results of a simple get response" do
    @protocol.execute "VALUE blah 0 5\r\nfucku\r\nEND\r\n"
    values = @protocol.values
    values.length.should == 1
    value = values[0]
    value.should_not be_nil
    value.data.should == "fucku"
    value.length.should == 5
    value.key.should == "blah"
    value.cas.should == 0
    value.flags.should == 0
  end
  
  it "should parse an empty get response" do
    @protocol.execute "END\r\n"
    @protocol.values.length.should == 0
  end
  
  it "should parse more than five values" do
    keys = %w(blah blaa blab blac blad blae blaf)
    dater = %w(fucku fucka fuckb fuckc fuckd fucke fuckf)
    @protocol.execute "VALUE blah 0 5\r\nfucku\r\nVALUE blaa 0 5\r\nfucka\r\nVALUE blab 0 5\r\nfuckb\r\nVALUE blac 0 5\r\nfuckc\r\nVALUE blad 0 5\r\nfuckd\r\nVALUE blae 0 5\r\nfucke\r\nVALUE blaf 0 5\r\nfuckf\r\nEND\r\n"
    @protocol.values.length.should == 7
    values = @protocol.values
    i = 0
    values.each do |value|
      value.should_not be_nil
      value.key.should == keys[i]
      value.data.should == dater[i]
      value.length.should == 5
      value.cas.should == 0
      value.flags.should == 0
      i += 1;
    end
  end
  
  it "should raise an error if the protocol gets retarded" do
    lambda { @protocol.execute "I like turtles\r\n" }.should raise_error(ProtocolError, "Memcache protocol encountered an error with char 'I' at pos 0\n")
  end
  
  it "should raise if the server sends regular error" do
    lambda { @protocol.execute "ERROR\r\n" }.should raise_error(CommandError)
  end
  
  it "should raise if the server sends a client error" do
    lambda { @protocol.execute "CLIENT_ERROR you did something really stupid\r\n" }.should raise_error(ClientError, "you did something really stupid")
  end
  
  it "should raise if the server sends a server error" do
    lambda { @protocol.execute "SERVER_ERROR should't see this really\r\n" }.should raise_error(ServerError, "should't see this really")
  end
end