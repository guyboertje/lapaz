
if ENV['LAPAZ_ENV']
  LpzEnv = ENV['LAPAZ_ENV'].downcase.to_sym
else
  LpzEnv = :devl
end

PortPfx = case LpzEnv
when :prod, :production
  "1"
when :stage
  "2"
else
  "3"
end

root_dir = File.expand_path(File.dirname(__FILE__))

%W(lib config app).each do |path|
  fullpath = File.join(root_dir,path)
  $LOAD_PATH.unshift(fullpath) unless $LOAD_PATH.include?(fullpath)
end

require File.join('lapaz','lapaz_conf')

%W(thread rubygems ffi-rzmq bert yaml uuid usher).each {|lib| require lib }
# mongo
require 'config'
require 'lapaz'
require 'app'

App.start("test_app")
