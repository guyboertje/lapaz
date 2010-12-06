def add_app_url_handlers(_)

  Router.configure _ do

    url_handlers do
      build :path_pattern => '/handlertest/purchases/:id.:format', :lapaz_route => 'purchases/start', :view_template=>'purchases.erb', :view_layout=>'default.erb'
    end

  end
end
