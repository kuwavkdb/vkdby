# frozen_string_literal: true

Rails.application.routes.draw do
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  resource :password, only: %i[edit update]

  namespace :admin do
    root to: 'users#index'
    resources :users
    resources :units do
      resources :unit_logs
      resources :unit_people, only: %i[create edit update destroy] do
        collection do
          patch :reorder
        end
      end
    end
    resources :people do
      resources :person_logs do
        collection do
          patch :reorder
        end
      end
    end

    resources :index_groups do
      member do
        patch :reorder_indices
        post :move_indices
        post :detach_indices
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root 'units#index'

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # Kana Indices
  get '/index/:index_group', to: 'indices#index', as: :indices_group
  get '/index/show/:id', to: 'indices#show', as: :index_show

  resources :people, param: :key, only: %i[index show], constraints: { key: %r{[^/]+} }
  resources :units, param: :key, only: %i[index show], constraints: { key: %r{[^/]+} }

  # Legacy redirects for .html extensions
  get '/:old_key.html', to: 'legacy_redirects#show', constraints: { old_key: %r{[^/]+} }

  get '/:key', to: 'profiles#show', as: :profile, constraints: { key: %r{[^/]+} }
end
