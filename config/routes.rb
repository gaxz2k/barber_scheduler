Rails.application.routes.draw do
  devise_for :users
  root to: "appointments#index"

  namespace :admin do
    root to: "home#index"
    resources :professionals
    resources :services
    resources :appointments
  end
  resources :appointments, only: [ :index, :show, :new, :create ]
  get "up" => "rails/health#show", as: :rails_health_check
end
