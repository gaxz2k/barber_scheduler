Rails.application.routes.draw do
  devise_for :users
  root to: "appointments#index"

  namespace :admin do
    root to: "home#index"
    resources :professionals
    resources :services
    resources :appointments
    resources :barbershop_photos, only: [ :index, :new, :create, :edit, :update, :destroy ]
  end

  get "appointments/availability", to: "appointments#availability", as: :availability
  get "appointments/confirmation/:token", to: "appointments#confirmation", as: :appointment_confirmation
  resources :appointments, only: [ :index, :new, :create ]
  get "up" => "rails/health#show", as: :rails_health_check
end
