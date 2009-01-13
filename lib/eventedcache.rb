ROOT = File.expand_path(File.dirname(__FILE__) + "/../")

require 'rubygems'
require 'eventmachine'

require "#{ROOT}/ext/memcache_protocol"
require "#{ROOT}/lib/eventedcache/connection"