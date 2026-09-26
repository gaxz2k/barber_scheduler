# frozen_string_literal: true

# SQL do limite de fotos publicadas, em uma fonte só.
#
# A migration 20260926220000 e o initializer que garante a estrutura no boot
# usam exatamente estas definições, para que as duas não possam divergir.
#
# Fica em lib/ e não em app/models/concerns porque não é um concern: é um módulo
# de constantes e SQL, sem estado e sem mixin.
module BarbershopPhotoPublishedLimit
  MAX_PUBLISHED_PHOTOS = 6
  TRIGGER_NAME = "trg_barbershop_photos_published_limit"
  FUNCTION_NAME = "enforce_barbershop_photos_published_limit"

  module_function

  def function_sql
    <<~SQL
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
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
  end

  def trigger_sql
    <<~SQL.squish
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON barbershop_photos;
      CREATE TRIGGER #{TRIGGER_NAME}
      BEFORE INSERT OR UPDATE ON barbershop_photos
      FOR EACH ROW EXECUTE FUNCTION #{FUNCTION_NAME}();
    SQL
  end

  def drop_sql
    <<~SQL.squish
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON barbershop_photos;
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
