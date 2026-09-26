class AddPublishedSlotToBarbershopPhotos < ActiveRecord::Migration[8.1]
  # A validação de Rubi (BarbershopPhoto#published_gallery_limit) conta as fotos
  # ativas e rejeita a sétima. Duas requisições simultâneas podem ler 5 e gravar
  # 6, deixando 6 no total; ou ler 6 e gravar 6, deixando 12. A contagem é uma
  # leitura seguida de escrita, sem nada que impeça a corrida no meio.
  #
  # Um trigger no banco fecha a janela: a verificação acontece dentro do mesmo
  # statement INSERT/UPDATE, então duas inserções concorrentes são serializadas
  # pelo lock de linha do próprio PostgreSQL e a segunda já vê a primeira.
  #
  # A linha só ocupa o slot quando está ativa, o que preserva o comportamento de
  # poder ter um número ilimitado de fotos inativas guardadas.
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

        -- A linha que está sendo alterada é excluída da contagem: em um UPDATE
        -- que ativa uma foto inativa, ela própria ainda não está gravada, e em
        -- um INSERT o id é novo. Contar sem o filtro bloquearia o próprio
        -- registro recém-nascido quando a galeria já estiver cheia.
        SELECT count(*) INTO published_count
          FROM barbershop_photos
          WHERE active AND id IS DISTINCT FROM NEW.id;

        IF published_count >= 6 THEN
          RAISE EXCEPTION 'limite de 6 fotos publicadas'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

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
