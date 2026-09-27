# Barbearia Senhor R

Sistema de agendamento da Barbearia Senhor R. Ruby on Rails 8.1, PostgreSQL,
Redis, Vite, React e TypeScript.

O cliente escolhe serviço, profissional e horário sem cadastro; a equipe
confirma, cancela e gerencia tudo por um painel administrativo protegido por
Devise.

## Requisitos

- Ruby 3.4.10 (veja `.ruby-version`)
- Node.js 20 ou superior, com npm
- PostgreSQL
- Redis

## Configuração

```bash
bundle install
npm install
```

As variáveis de ambiente são lidas direto do ambiente, sem arquivo `.env`
obrigatório. As que importam:

| Variável | Padrão | Para quê |
| --- | --- | --- |
| `POSTGRES_HOST` | `localhost` | Host do PostgreSQL |
| `POSTGRES_USER` | `postgres` | Usuário do PostgreSQL |
| `POSTGRES_PASSWORD` | — | Senha do PostgreSQL |
| `POSTGRES_DATABASE` | `barber_scheduler_<env>` | Nome do banco |
| `REDIS_URL` | — | Fila e cache |

## Banco de dados

```bash
bin/rails db:prepare
bin/rails db:seed
```

`db:prepare` cria o banco e aplica as migrations. `db:seed` carrega o catálogo
da barbearia — profissionais, serviços e o horário de funcionamento da unidade
principal — e é idempotente: pode rodar quantas vezes precisar, em qualquer
ambiente, sem duplicar nada.

O passo do seed não é opcional para uso real. Sem ele a aplicação sobe, mas o
agendamento público não tem serviço nem profissional para oferecer, e a agenda
de qualquer dia vem vazia porque nenhuma unidade tem expediente.

O seed também sobrescreve o horário da unidade principal a cada execução. Ele
é a configuração de demonstração; quem quiser o próprio expediente usa a tela
**Unidades** do painel, e aceitar o valor do seed é o preço de rodar `db:seed`
de novo.

> Um trigger do banco (o limite de seis fotos publicadas) não é representado em
> `db/schema.rb`, e `db:prepare` marca todas as versões do dump como já
> aplicadas. Por isso o trigger é garantido no boot por
> `config/initializers/barbershop_photo_published_limit.rb`, e não depende do
> passo de seed. A migration correspondente existe para quem migra uma base já
> existente.

## Front-end

```bash
npm run dev      # servidor de desenvolvimento do Vite
npm run build    # build de produção
npm run check    # testes (Vitest) + verificação de tipos
```

O diretório de saída do build é resolvido por `frontend/viteOutputDir.ts`, a
partir do `config/vite.json` que o `vite_ruby` também lê. A regra do ambiente e a
do diretório estão na mesma fonte do lado Ruby (`Rails.env` e o merge da seção
`all`), para que as duas pontas não{divergam} — quando divergem, toda página
responde 500 com `ViteRuby::MissingEntrypointError`.

## Testes

```bash
RAILS_ENV=test bundle exec rspec   # Ruby: models, services e requests
npm run check                      # Front-end: Vitest e TypeScript
bundle exec rubocop                # Estilo
bundle exec brakeman --no-pager     # Segurança
```

A suíte de RSpec só roda em `RAILS_ENV=test`. O hook de limpeza em
`spec/rails_helper.rb` aborta em qualquer outro ambiente, para que um
`RAILS_ENV=development bundle exec rspec` acidental não apague o banco de
desenvolvimento.

## Seed

O catálogo vem de `db/seeds.rb`:

- Profissionais: Gustavo, Richard e Marcus.
- Serviços: Corte (30min), Barba (30min), Corte + Barba (60min), Pigmentação
  (45min) e Platinado (120min).
- Unidade principal `/<slug da barbearia>`: segunda a sábado, 08:00–19:00.

Fotos, clientes e agendamentos **não** são semeados: são dados de operação e
pertencem a quem opera a barbearia. Um administrador precisa ser criado
manualmente no primeiro acesso:

```bash
bin/rails console
> User.create!(email: "voce@exemplo.com", password: "senha-forte", admin: true)
```

## Administração

O painel fica em `/admin` e exige login com uma conta `admin: true`. Sem conta
admin, nenhuma página administrativa responde.
