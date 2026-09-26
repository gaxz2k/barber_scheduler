class AddPublishedSlotToBarbershopPhotos < ActiveRecord::Migration[8.1]
  MAX_PUBLISHED_PHOTOS = 6

  # O limite de seis fotos publicadas era validado só em Rubi, numa contagem
  # seguida de escrita. Duas requisições simultâneas podem ler 5 e gravar 6, ou
  # ler 6 e gravar 6, e a galeria passa do limite sem que nenhuma validação
  # perceba. Um trigger no banco fecha a janela: a verificação roda dentro do
  # mesmo statement, então a segunda inserção concorrente já vê a primeira.
  #
  # A linha só ocupa slot quando está ativa, o que preserva o comportamento de
  # poder guardar um número ilimitado de fotos inativas.
  #
  # ATENÇÃO: um trigger não vive em db/schema.rb. `db:prepare` e `db:schema:load`
  # carregam o dump do schema e marcam todas as versões dele como aplicadas,
  # então esta migration é pulada e o trigger nunca é criado — foi exatamente o
  # que aconteceu no primeiro CI desta PR, e também numa base nova criada por
  # `db:prepare`. Por isso o CI roda `db:migrate` de verdade, e a função abaixo
  # é idempotente, para poder ser reaplicada por qualquer caminho de setup.
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION enforce_barbershop_photos_published_limit()
      RETURNS TRIGGER AS $$
      DECLARE
        published_count integer;
      BEGIN
        -- UPDATE que não ocupa slot novo não é limitado: renomear a legenda ou
        -- reposicionar uma foto já publicada continua possível com a galeria
        -- cheia. Isso espelha a validação de Rubi, que só conta quando
        -- will_save_change_to_active?.
        IF NOT NEW.active THEN
          RETURN NEW;
        END IF;

        IF TG_OP = 'UPDATE' AND OLD.active THEN
          RETURN NEW;
        END IF;

        -- A linha sendo alterada é excluída da contagem: em um UPDATE que ativa
        -- uma foto inativa, ela própria ainda não está gravada, e em um INSERT o
        -- id é novo. Contar sem o filtro bloquearia o próprio registro
        -- recém-nascido quando a galeria já estiver cheia.
        SELECT count(*) INTO published_count
          FROM barbershop_photos
          WHERE active AND id IS DISTINCT FROM NEW.id;

        IF published_count >= #{MAX_PUBLISHED_PHOTOS} THEN
          RAISE EXCEPTION 'limite de #{MAX_PUBLISHED_PHOTOS} fotos publicadas'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # DROP antes de CREATE: esta migration pode ser reaplicada por um caminho
    # que já criou o trigger (db:migrate depois de um db:prepare), e
    # CREATE TRIGGER falha se o trigger já existe.
    execute "DROP TRIGGER IF EXISTS trg_barbershop_photos_published_limit ON barbershop_photos;"

    execute <<~SQL.squish
      CREATE TRIGGER trg_barbershop_photos_published_limit
      BEFORE INSERT OR UPDATE ON barbershop_photos
      FOR EACH ROW EXECUTE FUNCTION enforce_barbershop_photos_published_limit();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS trg_barbershop_photos_published_limit ON barbershop_photos;"
    execute "DROP FUNCTION IF EXISTS enforce_barbershop_photos_published_limit();"
  end
end
