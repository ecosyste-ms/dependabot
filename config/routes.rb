require 'sidekiq/web'

Sidekiq::Web.use Rack::Auth::Basic do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])) &
    ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"]))
end if Rails.env.production?

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/docs'
  mount Rswag::Api::Engine => '/docs'
  
  mount Sidekiq::Web => "/sidekiq"
  mount PgHero::Engine, at: "pghero"

  namespace :api, :defaults => {:format => :json} do
    namespace :v1 do
      get 'repositories/lookup', to: 'repositories#lookup', as: :repositories_lookup
      
      resources :packages, only: [:index] do
        collection do
          get 'lookup', to: 'packages#lookup'
          get 'ecosystems'
          get ':ecosystem/:name', to: 'packages#show', as: :show, constraints: { ecosystem: /[^\/]+/, name: /.+/ }
          get ':ecosystem', to: 'packages#index', constraints: { ecosystem: /[^\/]+/ }
        end
      end
      
      resources :issues, only: [] do
        resources :packages, only: [:index], controller: 'issue_packages'
      end
      
      resources :advisories, only: [:index, :show] do
        collection do
          get 'lookup'
        end
        member do
          get 'issues'
        end
      end
      
      resources :hosts, constraints: { id: /.*/ }, only: [:index, :show] do
        resources :repositories, constraints: { id: /.*/ }, only: [:index, :show] do
          resources :issues, constraints: { id: /.*/ }, only: [:index, :show]
          member do
            get 'ping', to: 'repositories#ping'
          end
        end
        resources :authors, constraints: { id: /.*/ }, only: [:index, :show]
        resources :owners, constraints: { id: /.*/ }, only: [:index, :show] do
          member do
            get 'maintainers', to: 'owners#maintainers'
          end
        end
      end
    end
  end

  get 'repositories/lookup', to: 'repositories#lookup', as: :lookup_repositories

  resources :hosts, constraints: { id: /.*/ }, only: [:index, :show], :defaults => {:format => :html} do
    resources :repositories, constraints: { id: /.*/ }, only: [:index, :show] do
      # chart views disabled for now due to routing errors
      # member do
      #   get 'charts', to: 'repositories#charts'
      #   get 'chart_data', to: 'repositories#chart_data'
      # end
      resources :issues, constraints: { id: /.*/ }, only: [:show]
      member do
        get 'feed', to: 'repositories#feed'
      end
    end
    resources :authors, constraints: { id: /.*/ }, only: [:index, :show]
    resources :owners, constraints: { id: /.*/ }, only: [:index, :show] do
      member do
        get 'issues', to: 'owners#issues'
        get 'feed', to: 'owners#feed'
      end
    end
  end

  get '/chart_data', to: 'home#chart_data', as: :chart_data
  get '/feed', to: 'home#feed', as: :global_feed

  resources :packages, only: [:index] do
    collection do
      get 'search'
      get ':ecosystem/chart_data', to: 'packages#ecosystem_chart_data', as: :ecosystem_chart_data, constraints: { ecosystem: /[^\/]+/ }
      get ':ecosystem/issues', to: 'packages#ecosystem_issues', as: :ecosystem_issues, constraints: { ecosystem: /[^\/]+/ }
      get ':ecosystem/feed', to: 'packages#ecosystem_feed', as: :ecosystem_feed, constraints: { ecosystem: /[^\/]+/ }
      get ':ecosystem', to: 'packages#ecosystem', as: :ecosystem, constraints: { ecosystem: /[^\/]+/ }
      get ':ecosystem/:name/feed', to: 'packages#feed', as: :feed, constraints: { ecosystem: /[^\/]+/, name: /.+/ }
      get ':ecosystem/:name', to: 'packages#show', as: :show, constraints: { ecosystem: /[^\/]+/, name: /.+/ }
    end
  end

  resources :exports, only: [:index], path: 'open-data'
  resources :imports, only: [:index]
  
  resources :advisories, only: [:index, :show] do
    member do
      get 'issues', to: 'advisories#issues'
    end
  end

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  root "home#index"
end
