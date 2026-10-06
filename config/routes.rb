Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get  "sign_in/otp", to: "sessions#otp", as: :sign_in_otp
  post "sign_in/otp", to: "sessions#otp_create"
  get  "sign_in/password", to: "sessions#password", as: :sign_in_password
  post "sign_in/password", to: "sessions#password_create"
  get  "sign_in/magic", to: "sessions#magic", as: :sign_in_magic
  get  "sign_in/whatsapp", to: "sessions#whatsapp", as: :sign_in_whatsapp
  post "dev_sign_in", to: "sessions#dev" if Rails.env.development?

  get  "sign_up", to: "signups#show", as: :sign_up

  resources :sessions, only: [ :index, :show, :destroy ]
  delete "sign_out", to: "sessions#destroy_current", as: :sign_out
  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
  end
  root "home#index"

  get "pricing", to: "pricing#show", as: :pricing
  get "use-cases/:slug", to: "use_cases#show", as: :use_case
  resources :documents, only: [ :show ], param: :slug


  # Customer portal at /app (landing page stays at /)
  scope :app do
    get "/", to: redirect(path: "/app/recent"), as: :app

    resources :library_media, only: %i[create update destroy], path: "library/media" do
      member do
        post :extract
        patch :apply_extraction
      end
    end

    scope path: "library", module: :accounts do
      get "media/:id", to: "library#show", as: :library_item
      get "(:root(/:child))", to: "folders#show", as: :library_folders
      post "(:root)", to: "folders#create"
      patch ":root(/:child)", to: "folders#update"
      delete ":root(/:child)", to: "folders#destroy"
    end

    scope path: "instagram", module: :accounts, as: :instagram do
      get "profile", to: "instagram#show"
      delete "profile", to: "instagram#destroy"
      resources :posts, only: %i[index show destroy] do
        member do
          post :publish
          post :react
        end
      end
    end

    scope module: :accounts do
      get "overview", to: "overview#show", as: :overview
      get "recent", to: "recent#show", as: :recent
      get "calendar", to: "calendar#show", as: :calendar
      resource :business, only: [ :show, :update ], controller: "business"
      resources :services, except: :show
      resources :shots, except: :show
      resources :layers, only: %i[index show] do
        get :canvas, on: :member
      end
      resources :recipes, except: :edit do
        patch :rename_group, on: :collection
        get "tracks/:effect", action: :track, on: :collection, as: :track
      end
      resources :styles, except: :show
      resources :links, only: %i[index create show destroy] do
        resources :crawls, only: :create do
          patch :apply, on: :member
        end
        resources :suggestions, only: [] do
          member do
            patch :apply
            patch :reject
          end
        end
      end
      resources :reviews, only: %i[index update destroy]
      resource :subscription, only: [ :show ]
      get "whatsapp", to: "whatsapp#show", as: :whatsapp
      delete "whatsapp", to: "whatsapp#destroy"
      get "onboarding/:tab", to: "onboarding#show", as: :onboarding, tab: /steps|media/, defaults: { tab: "steps" }
      post "onboarding/reset", to: "onboarding#reset", as: :onboarding_reset
      post "onboarding/ask", to: "onboarding#ask", as: :onboarding_ask
      post "onboarding/dashboard_link", to: "onboarding#dashboard_link", as: :onboarding_dashboard_link
      get "admin", to: "admin#show", as: :admin
    end

    scope path: "subscription", as: "subscription" do
      post "checkout", to: "accounts#checkout"
      post "portal", to: "accounts#portal"
      patch "status", to: "accounts#subscription_status"
    end

    scope path: "profile", as: "profile", module: :accounts do
      resource :settings, only: [ :show, :update ]
      get "instagram/authorize", to: "instagram_authorizations#new", as: :instagram_authorize
      get "instagram/callback", to: "instagram_authorizations#callback", as: :instagram_callback
      post "instagram/refresh", to: "instagram_authorizations#refresh", as: :instagram_refresh
    end
  end

  post "stripe/webhook", to: "stripe_webhooks#create"
  post "telegram/webhook", to: "telegram_webhooks#create"
  get  "whatsapp/webhook", to: "whatsapp_webhooks#show"
  post "whatsapp/webhook", to: "whatsapp_webhooks#create"

  # Guest magic-link subscribe (helpers: new_subscribe_path / subscribe_path)
  resource :subscription, only: %i[new create], as: :subscribe
  get "subscription/thanks", to: "subscriptions#thanks", as: :subscription_thanks
  get "subscription/access", to: "subscriptions/accesses#show", as: :subscription_access

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  constraints ->(request) { Session.find_by(id: request.cookie_jar.signed[:session_token])&.user&.admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
