include Lapaz

app = Router.application('app_b')

%W(system producers processors consumers models routes url_handlers).each do |d|
  Dir.glob(File.join("app", d, "**", "*.rb")).each do |f|
    load f
  end
end

add_sys_config app
add_app_routes app
add_app_url_handlers app

p app.services.inspect
Thread.abort_on_exception = true
app.run()

