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
    end
    resources :authors, constraints: { id: /.*/ }, only: [:index, :show]
    resources :owners, constraints: { id: /.*/ }, only: [:index, :show]
  end

  get '/dependabot', to: 'issues#dependabot', as: :dependabot
  get '/chart_data', to: 'home#chart_data', as: :chart_data

  resources :packages, only: [:index] do
    collection do
      get 'search'
      get ':ecosystem/chart_data', to: 'packages#ecosystem_chart_data', as: :ecosystem_chart_data, constraints: { ecosystem: /[^\/]+/ }
      get ':ecosystem', to: 'packages#ecosystem', as: :ecosystem, constraints: { ecosystem: /[^\/]+/ }
      get ':ecosystem/:name', to: 'packages#show', as: :show, constraints: { ecosystem: /[^\/]+/, name: /.+/ }
    end
  end

  resources :exports, only: [:index], path: 'open-data'

  get '/404', to: 'errors#not_found'
  get '/422', to: 'errors#unprocessable'
  get '/500', to: 'errors#internal'

  root "home#index"
end
