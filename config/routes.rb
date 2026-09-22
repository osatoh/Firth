Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Google sign-in (the OmniAuth callback and failure endpoints, plus sign-out)
  get "auth/google_oauth2/callback", to: "sessions#create"
  post "auth/google_oauth2/callback", to: "sessions#create"
  get "auth/failure", to: "sessions#failure"
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  # No feed page of its own: the list is the only view onto a feed.
  resources :feeds, except: :show
  resources :articles, only: %i[index show] do
    # POST, not GET, so link prefetchers and cross-site requests cannot mark articles read.
    post :visit, on: :member
    resource :summary, only: :create, module: :articles
  end

  resource :settings, only: %i[edit update] do
    resource :api_key, only: :destroy, module: :settings
    resource :account, only: :destroy, module: :settings
  end

  root "pages#landing"
end
