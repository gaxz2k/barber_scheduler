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

  get "appointments/confirmation/:token", to: "appointments#confirmation", as: :appointment_confirmation

  # A unidade é escolhida na URL, e não em campo de formulário: a escolha
  # sobrevive à troca de unidade depois, e o link de confirmação aponta para
  # a mesma unidade. A unidade é o mesmo tenant com `slug` próprio, então a
  # resolução continua sendo a da barbearia pelo subdomínio.
  #
  # `availability` fica dentro do scope por necessidade, e não por organização:
  # a agenda que ele devolve é a da unidade, então pedir a agenda sem
  # unidade na URL é pedir a agenda de lugar nenhum.
  scope "/barbearia/unidades/:unidade_slug", as: :unidade do
    resources :appointments, only: [ :index, :new, :create ], path: ""
    get "appointments/availability", to: "appointments#availability", as: :availability
  end

  get "appointments/availability", to: "appointments#availability", as: :availability

  resources :appointments, only: [ :index, :new, :create ]
  get "up" => "rails/health#show", as: :rails_health_check
end
