Rails.application.routes.draw do
  devise_for :users
  root to: "appointments#index"

  namespace :admin do
    root to: "home#index"
    resources :barbers
    resources :services
  end
  resources :appointments
  resources :barbers
  get "up" => "rails/health#show", as: :rails_health_check
end
