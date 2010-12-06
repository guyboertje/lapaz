
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

RootDir = root_dir = File.expand_path(File.dirname(__FILE__))

%W(lib config app).each do |path|
  fullpath = File.join(root_dir,path)
  $LOAD_PATH.unshift(fullpath) unless $LOAD_PATH.include?(fullpath)
end

AppDir = File.join(root_dir,'app')

%W(thread yaml rubygems ffi-rzmq bert uuid blockenspiel usher erubis tilt json jmongo ).each {|lib| require lib }

#load up low level stuff
%W(lapaz_conf transport serializer).each do |lib|
  require File.join('lapaz',lib)
end

Tilt.register 'erb', Tilt::ErubisTemplate

require 'config'
require 'lapaz'
require 'app'
