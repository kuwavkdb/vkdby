# frozen_string_literal: true

Rails.application.routes.draw do
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  resource :password, only: %i[edit update]

  namespace :admin do
    root to: 'users#index'
    resources :users
    resources :external_sites
    resources :units do
      collection do
        get :search
      end
      member do
        patch :undiscard
      end
      resources :unit_logs
      resources :unit_people, only: %i[create edit update destroy] do
        collection do
          patch :reorder
        end
      end
      resources :unit_snapshots, except: %i[show] do
        member do
          post :copy
        end
        collection do
          patch :reorder
        end
        resources :snapshot_people, only: %i[create destroy edit update] do
          collection do
            patch :reorder
          end
        end
      end
    end
    resources :people do
      collection do
        get :search
      end
      member do
        patch :undiscard
      end
      resources :person_logs do
        collection do
          patch :reorder
        end
      end
    end

    resources :trends

    resources :index_groups do
      member do
        patch :reorder_indices
        post :move_indices
        post :detach_indices
      end
    end

    resources :items

    resources :tag_indices, only: %i[update] do
      collection do
        post :bulk_update
      end
    end

    resources :custom_pages do
      member do
        patch :undiscard
      end
    end

    resources :sections, only: %i[new create edit update destroy] do
      member do
        patch :undiscard
      end
      collection do
        patch :reorder
      end
    end

    resources :update_logs, only: [] do
      member do
        post :restore
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  root 'custom_pages#index_page'

  mount Lookbook::Engine, at: '/lookbook' if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # Kana Indices
  get '/index', to: 'indices#groups', as: :indices_groups
  get '/index/:index_group', to: 'indices#index', as: :indices_group
  get '/index/show/:id', to: 'indices#show', as: :index_show

  resources :people, param: :key, only: %i[index show], constraints: { key: %r{[^/]+} }
  resources :units, param: :key, only: %i[index show], constraints: { key: %r{[^/]+} } do
    collection do
      get :search
    end
  end
  resources :trends, only: %i[index show]
  resources :items, only: %i[index show]

  # Date index page (MUST be before other date routes!)
  get '/date', to: 'yearly#index', as: :date_index

  # Yearly page (MUST be before monthly and daily routes!)
  get '/date/:year', to: 'yearly#show', as: :yearly,
                     constraints: { year: /\d{4}/ }

  # Monthly page (MUST be before daily route!)
  get '/date/:year/:month', to: 'monthly#show', as: :monthly,
                            constraints: { year: /\d{4}/, month: /\d{1,2}/ }

  # Birthday page (year-agnostic: /date/-/MM/DD)
  get '/date/-/:month/:day', to: 'daily#show', as: :birthday_date,
                             constraints: { month: /\d{1,2}/, day: /\d{1,2}/ }

  # Daily page
  get '/date/:year/:month/:day', to: 'daily#show', as: :daily,
                                 constraints: { year: /\d{4}/, month: /\d{1,2}/, day: /\d{1,2}/ }

  # Custom pages
  get '/pages/:key', to: 'custom_pages#show', as: :custom_page,
                     constraints: { key: /[a-z0-9_-]+/ }

  # Cross-search
  get 'search', to: 'search#index'

  # Legacy redirects for .html extensions
  get '/:old_key.html', to: 'legacy_redirects#show', constraints: { old_key: %r{[^/]+} }

  # Legacy redirects for /NEWS_{id} format
  get '/NEWS_:id', to: 'legacy_redirects#news_redirect', constraints: { id: /\d+/ }

  # Legacy redirects for /ITEM_{asin} format
  get '/ITEM_:asin', to: 'legacy_redirects#item_redirect', constraints: { asin: /[A-Z0-9]+/ }

  get '/:key/snapshots/:id/members', to: 'profiles#snapshot_members', as: :snapshot_members,
                                     constraints: { key: %r{[^/]+} }
  get '/:key', to: 'profiles#show', as: :profile, constraints: { key: %r{[^/]+} }
end
