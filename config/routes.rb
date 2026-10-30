Rails.application.routes.draw do
  devise_for :users
  root to: "appointments#index"

  # A criação de uma barbearia. Fica antes de tudo porque é a única rota do
  # sistema que roda sem tenant: a requisição chega sem host de barbearia e sem
  # cookie, e é ela que produz o primeiro tenant. Por isso o controller não
  # herda de `ApplicationController` — o `around_action :use_current_barbershop`
  # do pai levantaria `RecordNotFound` antes de a tela aparecer.
  resources :barbershops, only: [ :new, :create ]

  # Desvio de desenvolvimento para abrir uma barbearia sem subdomínio.
  #
  # `/t/barbearia-exemplo` serve a mesma tela que `barbearia-exemplo.localhost`,
  # e existe para um caso concreto: quem olha a demonstração de fora não tem
  # como resolver `slug.<algo>`. Um túnel efêmero entrega um único hostname, e
  # prefixar `slug.` nele é recusado na borda — o endereço simplesmente não
  # abre.
  #
  # A rota aponta para `appointments#index` — e não para uma ação deste
  # controller — porque o tenant chega pelo `around_action`, e uma action
  # intermediária reentraria na cadeia de callbacks. O que `/t/<slug>` faz de
  # especial é gravar o cookie do desvio, e a partir daí a navegação é comum.
  #
  # Só existe fora de produção, e `barbershop_from_cookie` também se recusa lá:
  # um cookie que resolve tenant em produção daria a qualquer cookie de sessão
  # a tela de uma barbearia.
  unless Rails.env.production?
    get "/t/:slug", to: "appointments#index", as: :tenant_path

    # A vitrine da fundação visual (fase 1 do redesign): tokens, componentes,
    # ícones e ilustrações, lado a lado, fora de qualquer tenant. Mesma regra
    # do desvio acima — só existe fora de produção, porque é ferramenta de
    # quem constrói a tela, não tela que um cliente de barbearia deveria
    # encontrar.
    get "/style-guide", to: "style_guide#index", as: :style_guide
  end

  namespace :admin do
    root to: "home#index"
    resources :professionals
    resources :services
    resources :appointments
    resources :barbershop_photos, only: [ :index, :new, :create, :edit, :update, :destroy ]
    # A unidade é onde o horário de funcionamento se cadastra, e é por ela que
    # `missing_setup` aponta quando o expediente falta.
    resources :barbershop_units, only: [ :index, :new, :create, :edit, :update ]
    resource :shop_setting, only: [ :edit, :update ]
  end

  get "appointments/confirmation/:token", to: "appointments#confirmation", as: :appointment_confirmation

  # "Consultar meus Agendamentos", fiel à gaveta da referência SimplesAgenda:
  # busca pelo telefone, sem login. Fora do escopo de unidade de propósito —
  # o cliente pode ter agendamentos em mais de uma unidade da mesma barbearia,
  # e a consulta é "meus agendamentos", não "meus agendamentos nesta loja".
  get "agendamentos/consultar", to: "appointments#lookup", as: :appointments_lookup

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
