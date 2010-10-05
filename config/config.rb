#M_CTX = ZMQ::Context.new(1)
lapazcfg.mongrel = LpzEnv, {:sender_id=>::UUID.generate,:scheme=>"tcp",:host=>"127.0.0.1",:req_port=>"9997",:rep_port=>"9996", :ctx=>ZMQ::Context.new(1), :conn=>nil}

#A_CTX = ZMQ::Context.new(1)
lapazcfg.app = LpzEnv, {:scheme=>"tcp",:host=>"127.0.0.1",:int_port=>"4066",:ext_port=>"4068", :int_endpt=>"", :ext_endpt=>"", :ctx=>ZMQ::Context.new(1)}
lapazcfg.app(LpzEnv) do |cfg|
  b = "#{cfg.scheme}://#{cfg.host}:#{PortPfx}"
  cfg.ext_endpt = b + cfg.ext_port
  cfg.int_endpt = b + cfg.int_port
end

#db = nil
#lapazcfg.mongo = LpzEnv, {:host=>"127.0.0.1",:port=>"7037",:db=>"lapaz_md",:con_cfg=>{:pool_size => 5, :timeout => 3.0},:con=>nil, :db=>nil}
#lapazcfg.mongo(LpzEnv) do |cfg|
#  cfg.con = Mongo::Connection.new(cfg.host, (PortPfx + cfg.port).to_i, cfg.con_cfg)
#  db = cfg.db = cfg.con.db("lapaz")
#end

# populate the db

[:INT, :TERM].each { |sig| trap(sig){ lapazcfg.app(LpzEnv).ctx.terminate } }
