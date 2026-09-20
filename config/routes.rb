Rails.application.routes.draw do
  mount_avo
  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get  "sign_in/otp", to: "sessions#otp", as: :sign_in_otp
  post "sign_in/otp", to: "sessions#otp_create"
  get  "sign_in/magic", to: "sessions#magic", as: :sign_in_magic
  get  "sign_in/password", to: "sessions#password", as: :sign_in_password
  post "sign_in/password", to: "sessions#password_create"
  post "dev_sign_in", to: "sessions#dev" if Rails.env.development?
  get  "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resources :sessions, only: [ :index, :show, :destroy ]
  resource  :password, only: [ :edit, :update ]
  namespace :identity do
    resource :email,              only: [ :edit, :update ]
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end
  root "home#index"

  get "try", to: "waitlists#new", as: :try
  post "try", to: "waitlists#create"
  get "try/thanks", to: "waitlists#thanks", as: :try_thanks

  get "pricing", to: "pricing#show", as: :pricing
  get "use-cases/:slug", to: "use_cases#show", as: :use_case
  resources :documents, only: [ :show ], param: :slug


  resource :account, only: [ :show ] do
    scope module: :accounts do
      resource :settings, only: [ :show ]
      resource :integrations, only: [ :show, :update ]
      resource :subscription, only: [ :show ]
    end
    post :checkout
    post :portal
    patch :subscription_status
  end
  get "library", to: redirect("/account")
  delete "library/media/:id", to: "library_media#destroy", as: :library_media
  post "library/media/:id/instagram_story", to: "instagram_stories#create", as: :library_instagram_story
  post "library/media/:id/improve", to: "library_media_improves#create", as: :library_improve

  post "stripe/webhook", to: "stripe_webhooks#create"
  post "telegram/webhook", to: "telegram_webhooks#create"

  resource :subscription, only: %i[new create]
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
