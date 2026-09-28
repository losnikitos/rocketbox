Rails.application.routes.draw do
  ActiveAdmin.routes(self)
  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get  "sign_in/otp", to: "sessions#otp", as: :sign_in_otp
  post "sign_in/otp", to: "sessions#otp_create"
  get  "sign_in/magic", to: "sessions#magic", as: :sign_in_magic
  post "dev_sign_in", to: "sessions#dev" if Rails.env.development?

  get  "sign_up", to: "signups#show", as: :sign_up
  get  "sign_up/name", to: "signups#name", as: :sign_up_name
  post "sign_up/name", to: "signups#name_submit"
  get  "sign_up/business", to: "signups#business", as: :sign_up_business
  post "sign_up/business", to: "signups#business_submit"
  get  "sign_up/email", to: "signups#email", as: :sign_up_email
  post "sign_up/email", to: "signups#email_submit"
  get  "sign_up/email_code", to: "signups#email_code", as: :sign_up_email_code
  post "sign_up/email_code", to: "signups#email_code_submit"
  get  "sign_up/whatsapp", to: "signups#whatsapp", as: :sign_up_whatsapp
  post "sign_up/whatsapp/skip", to: "signups#whatsapp_skip", as: :sign_up_whatsapp_skip

  resources :sessions, only: [ :index, :show, :destroy ]
  delete "sign_out", to: "sessions#destroy_current", as: :sign_out
  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
  end
  root "home#index"

  get "try", to: "waitlists#new", as: :try
  post "try", to: "waitlists#create"
  get "try/thanks", to: "waitlists#thanks", as: :try_thanks

  get "pricing", to: "pricing#show", as: :pricing
  get "use-cases/:slug", to: "use_cases#show", as: :use_case
  resources :documents, only: [ :show ], param: :slug


  # Customer portal at /app (landing page stays at /)
  scope :app do
    get "/", to: redirect("/app/library/uploads"), as: :app

    resource :account_selection, only: :update, module: :accounts

    scope path: "library", module: :accounts do
      get "/", to: redirect("/app/library/uploads")
      get "uploads", to: "library#uploads", as: :library_uploads
      get "uploads/:id", to: "library#show", as: :library_upload
    end

    scope path: "smm", module: :accounts, as: :smm do
      get "/", to: "smm#index", as: :root
      get "reels", to: "smm#reels"
      get "stories", to: "smm#stories"
      resources :posts, only: %i[index new create show] do
        member do
          post :publish
          post :react
        end
      end
    end

    scope module: :accounts do
      resource :business, only: [ :show, :update ], controller: "business"
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
      resource :integrations, only: [ :show, :update ]
      resource :subscription, only: [ :show ]
      get "onboarding", to: "onboarding#show", as: :onboarding
      post "onboarding/reset", to: "onboarding#reset", as: :onboarding_reset
    end

    scope path: "subscription", as: "subscription" do
      post "checkout", to: "accounts#checkout"
      post "portal", to: "accounts#portal"
      patch "status", to: "accounts#subscription_status"
    end

    scope path: "profile", as: "profile", module: :accounts do
      resource :settings, only: [ :show ]
      get "instagram/authorize", to: "instagram_authorizations#new", as: :instagram_authorize
      get "instagram/callback", to: "instagram_authorizations#callback", as: :instagram_callback
      post "instagram/refresh", to: "instagram_authorizations#refresh", as: :instagram_refresh
    end

    resources :library_media, only: %i[create update destroy], path: "library/media" do
      patch :bulk_update, on: :collection
      member do
        post :extract
        patch :apply_extraction
      end
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
