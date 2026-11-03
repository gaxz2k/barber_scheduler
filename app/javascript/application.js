// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Ativa o Turbo Drive de verdade (o gem "turbo-rails" já estava no Gemfile,
// mas faltava este import — sem ele a parte JS nunca carregava e todo link
// da aplicação fazia reload cheio da página, mesmo com data-turbo-track já
// configurado nos layouts). Importamos o Turbo antes dos controllers Stimulus,
// seguindo a ordem recomendada pelo próprio Hotwire, já que o Turbo precisa
// estar "ligado" antes de qualquer controller que dependa de eventos de
// navegação dele (turbo:load, turbo:visit etc.).
//
// É seguro ativar isso em todo o app porque os pontos onde a navegação
// PRECISA ser um reload de verdade (o passo atual do assistente de
// agendamento vem de query params lidos no servidor, não de um Frame/Stream)
// já foram marcados defensivamente com data: { turbo: false } em
// app/views/appointments/new.html.erb e _service_rows.html.erb — ver
// auditoria desses casos feita junto com esta mudança.
import "@hotwired/turbo-rails"
import "controllers"
