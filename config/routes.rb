Spree::Core::Engine.add_routes do

  resources :addresses

  namespace :admin do
  	resources :addresses
  end
  
end