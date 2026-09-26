class AddPublishedSlotToBarbershopPhotos < ActiveRecord::Migration[8.1]
  # O limite de seis fotos publicadas era validado só em Rubi, numa contagem
  # seguida de escrita. Duas requisições simultâneas podem ler 5 e gravar 6, ou
  # ler 6 e gravar 6, e a galeria passa do limite sem que nenhuma validação
  # perceba. Um trigger no banco fecha a janela: a verificação roda dentro do
  # mesmo statement, então a segunda inserção concorrente já vê a primeira.
  #
  # A linha só ocupa slot quando está ativa, o que preserva o comportamento de
  # poder guardar um número ilimitado de fotos inativas.
  #
  # O SQL vive em lib/barbershop_photo_published_limit.rb, compartilhado com o
  # initializer que garante a estrutura no boot, para que as duas peças não
  # possam divergir.
  #
  # ATENÇÃO: um trigger não vive em db/schema.rb. `db:prepare` e
  # `db:schema:load` marcam todas as versões do dump como já aplicadas, então esta
  # migration é pulada e o trigger nunca é criado — nem no CI, nem numa base nova
  # de produção. Por isso o initializer
  # config/initializers/barbershop_photo_published_limit.rb refaz a criação no
  # boot, e esta migration continua sendo o caminho explícito para quem migra uma
  # base já existente.
  def up
    execute BarbershopPhotoPublishedLimit.function_sql
    execute BarbershopPhotoPublishedLimit.trigger_sql
  end

  def down
    execute BarbershopPhotoPublishedLimit.drop_sql
  end
end
