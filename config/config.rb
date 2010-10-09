# when defining multiple apps for this runtime use the appname as the slice key
#  e.g. app 1 is called 'apollo' and app 2 'hermes'
#  to have separate slices of config add the app name into the set and get
#  lapazcfg('apollo').mongrel = {} and
#  lapazcfg('hermes').mongrel = {}

lapazcfg.mongrel = {:sender_id=>::UUID.generate,:scheme=>"tcp",:host=>"127.0.0.1",:req_port=>"9997",:rep_port=>"9996", :ctx=>ZMQ::Context.new(1), :conn=>nil}

lapazcfg.app = {:scheme=>"tcp",:host=>"127.0.0.1",:int_port=>"4066",:ext_port=>"4068", :int_endpt=>"", :ext_endpt=>"", :ctx=>ZMQ::Context.new(1)}
lapazcfg.app do |cfg|
  b = "#{cfg.scheme}://#{cfg.host}:#{PortPfx}"
  cfg.ext_endpt = b + cfg.ext_port
  cfg.int_endpt = b + cfg.int_port
end

vfolder = File.join(AppDir,"views")

lapazcfg.app_views = {:folder=>vfolder,:default_engine=>"erubis"}

#db = nil
#lapazcfg.mongo = {:host=>"127.0.0.1",:port=>"7037",:db=>"lapaz_md",:con_cfg=>{:pool_size => 5, :timeout => 3.0},:con=>nil, :db=>nil}
#lapazcfg.mongo do |cfg|
#  cfg.con = Mongo::Connection.new(cfg.host, (PortPfx + cfg.port).to_i, cfg.con_cfg)
#  db = cfg.db = cfg.con.db("lapaz")
#end

# populate the db

#[:INT, :TERM].each { |sig| trap(sig){ lapazcfg.app.ctx.terminate } }
