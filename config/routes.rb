Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root → group join/login page
  root "groups#new"

  # Group join / session
  get  "join",   to: "groups#new",    as: :join
  post "join",   to: "groups#create"
  delete "leave", to: "groups#destroy", as: :leave

  # Strategy catalog + selection
  get  "strategies",          to: "strategies#index",  as: :strategies
  post "strategies/:id/pick", to: "strategies#pick",   as: :pick_strategy

  # Waiting room (after selecting)
  get "waiting", to: "groups#waiting", as: :waiting

  # Admin panel (HTTP Basic Auth)
  get  "admin",                  to: "admin#index",            as: :admin
  patch "admin/rounds",          to: "admin#update_rounds",    as: :admin_update_rounds
  post "admin/run_tournament",   to: "admin#run_tournament",   as: :admin_run_tournament
  post "admin/reset_tournament", to: "admin#reset_tournament", as: :admin_reset_tournament

  # Results (public after tournament is done)
  get "results", to: "results#index", as: :results

  # Match replay (group-authenticated)
  get "my_matches",         to: "matches#index",  as: :my_matches
  get "my_matches/:id",     to: "matches#show",   as: :my_match
end
