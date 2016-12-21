Spree::Core::Engine.add_routes do
  match '/payumoney', :to => "payumoney#index", :as => :payumoney_proceed, via: [:get, :post]
  post '/payumoney/confirm', :to => "payumoney#confirm", :as => :payumoney_confirm
  post '/payumoney/cancel', :to => "payumoney#cancel", :as => :payumoney_cancel
end
