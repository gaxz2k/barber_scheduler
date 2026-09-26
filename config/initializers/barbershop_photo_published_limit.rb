# frozen_string_literal: true

# O limite de seis fotos publicadas é validado em Rubi por
# BarbershopPhoto#published_gallery_limit, e essa validação é uma contagem
# seguida de escrita: duas requisições simultâneas podem ler 5 e gravar 6, ou ler
# 6 e gravar 6, e a galeria passa do limite sem que nenhuma validação perceba.
#
# A barreira contra essa corrida é um trigger no banco.
#
# O problema: um trigger não vive em db/schema.rb. `db:prepare`, `db:schema:load`
# e qualquer base nova criada a partir do dump marcam todas as versões do schema
# como já aplicadas, então a migration 20260926220000 é pulada e o trigger nunca
# é criado — nem no CI, nem numa base nova de produção. Foi o que aconteceu na
# primeira execução desta mudança no CI: 195 exemplos, 1 falha, porque a sétima
# foto entrava sem resistência.
#
# Este initializer garante a estrutura no boot. É idempotente, roda em todos os
# ambientes e não depende de como o banco foi criado. Custa uma consulta de
# catálogo por processo, só no boot, nunca por requisição.
#
# A alternativa seria configurar structure.sql em vez de schema.rb, o que
# carregaria trigger e função no dump. É mais limpo, mas muda a forma como o
# schema é gerado em todo o projeto e exige um dump novo; a garantia no boot é
# local e reversível.
Rails.application.config.after_initialize do
  # Tarefas de banco (db:create, db:drop, db:prepare) inicializam a aplicação
  # antes de o banco existir, e algumas o apagam no meio do caminho. O trigger é
  # para a aplicação em uso, não para essas tarefas: se não há banco, tabela ou
  # conexão, não há nada a garantir.
  begin
    connection = ActiveRecord::Base.connection
    next unless connection.table_exists?("barbershop_photos")
    next if connection.select_value(
      "SELECT count(*) FROM pg_trigger WHERE tgname = #{connection.quote(BarbershopPhotoPublishedLimit::TRIGGER_NAME)}"
    ).to_i.positive?

    connection.execute(BarbershopPhotoPublishedLimit.function_sql)
    connection.execute(BarbershopPhotoPublishedLimit.trigger_sql)
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
    nil
  end
end
