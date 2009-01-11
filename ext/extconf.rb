require 'mkmf'

dir_config("ext")
have_library("c", "main")

create_makefile("memcache_protocol")