Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    passwords: "users/passwords"
  }

  root "pages#home"
  get "pricing", to: "pages#pricing"

  resource :account, only: :show
  resources :active_sessions, only: :destroy

  resources :checkouts, only: :create
  get "checkout/success", to: "checkouts#success", as: :checkout_success
  get "checkout/cancel",  to: "checkouts#cancel",  as: :checkout_cancel
  resource :billing_portal, only: :create

  post "webhooks/stripe", to: "webhooks#stripe"

  get "robots.txt"  => "seo#robots",  defaults: { format: "text" }
  get "sitemap.xml" => "seo#sitemap", defaults: { format: "xml" }

  get "up" => "rails/health#show", as: :rails_health_check
end
