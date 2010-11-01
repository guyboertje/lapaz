# when defining multiple apps for this runtime use the appname as the slice key
#  e.g. app 1 is called 'apollo' and app 2 'hermes'
#  to have separate slices of config add the app name into the set and get
#  lapazcfg('apollo').mongrel = {} and
#  lapazcfg('hermes').mongrel = {}

_ctx = ZMQ::Context.new(1)
lapazcfg.mongrel = {:sender_id=>::UUID.generate,:scheme=>"tcp",:host=>"127.0.0.1",:req_port=>"9997",:rep_port=>"9996", :ctx=>_ctx, :conn=>nil}

lapazcfg.ext = {:scheme=>"tcp",:host=>"127.0.0.1",:port=>"4040", :endpt=>"", :ctx=>_ctx}
lapazcfg.ext do |cfg|
  cfg.endpt = "#{cfg.scheme}://#{cfg.host}:#{PortPfx}#{cfg.port}"
end

#lapazcfg.ext = {:scheme=>"tcp",:host=>"127.0.0.1",:port=>"4066", :endpt=>"", :ctx=>_ctx}
lapazcfg.app = {:scheme=>"inproc",:key=>"lapaz", :endpt=>"", :ctx=>_ctx}
lapazcfg.app do |cfg|
  case cfg.scheme
  when "tcp"
    cfg.endpt = "#{cfg.scheme}://#{cfg.host}:#{PortPfx}#{cfg.port}"
  when "inproc"
    cfg.endpt = "#{cfg.scheme}://#{cfg.key}"
  end
end

vfolder = File.join(AppDir,"views")

lapazcfg.app_views = {:folder=>vfolder,:default_engine=>"erubis"}

db = nil
lapazcfg.mongo = {:host=>"127.0.0.1",:port=>"7037",:db_name=>"lapaz_md",:con_cfg=>{:pool_size => 5, :timeout => 3.0},:con=>nil, :db=>nil}
lapazcfg.mongo do |cfg|
  cfg.con = Mongo::Connection.new(cfg.host, (PortPfx + cfg.port).to_i, cfg.con_cfg)
  db = cfg.db = cfg.con.db(cfg.db_name)
end

# populate the db
unless db.has_collection?('prices')

  prices = [{'ccy_pair'=>'EURGBP','bid'=>'0.87330','offer'=>'0.87427'},{'ccy_pair'=>'GBPEUR','bid'=>'1.14381','offer'=>'1.14508'}]
  res = db.collection('prices').insert(prices)
  puts "Insert results: #{res.inspect}"

  purchase= {'id'=>'1234-DSF','contact_id'=>'886644','stock_id'=>'4521','notes'=>'rest of purchase object here'}
  res = db.collection('purchases').insert(purchase)
  puts "Insert results: #{res.inspect}"

  contact = {'id'=>'886644','name'=>'Bob Smith','age'=>32,'notes'=>'rest of contact object here'}
  res = db.collection('purchases').insert(contact)
  puts "Insert results: #{res.inspect}"

  stock = {'id'=>'4521','name'=>'Widget X','price'=>45.21,'ccy'=>'EUR','notes'=>'rest of stock object here'}
  res = db.collection('purchases').insert(stock)
  puts "Insert results: #{res.inspect}"

end
#[:INT, :TERM].each { |sig| trap(sig){ lapazcfg.app.ctx.terminate } }













