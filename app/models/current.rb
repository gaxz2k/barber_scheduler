# frozen_string_literal: true

# A barbearia da requisição atual.
#
# Existe um por processo e por requisição, via RequestStore, e nunca global em
# variável de classe. Um accessor global seria o jeito mais rápido de servir a
# agenda da barbearia errada para o cliente errado depois de um restart do
# Puma, que é exatamente o tipo de vazamento que multi-tenant precisa evitar.
#
# `Current.barbershop` só é preenchido por código que sabe qual é: o
# SubdomainResolver, na borda da requisição, ou um teste que monta o contexto
# na mão. Nada mais escreve aqui.
module Current
  class << self
    def barbershop
      attributes[:barbershop]
    end

    def barbershop=(barbershop)
      attributes[:barbershop] = barbershop
    end

    def barbershop_id
      barbershop&.id
    end

    # Limpa o contexto. No ciclo HTTP quem chama é o
    # `RequestStore::Middleware`, mas o momento importa e não é "logo depois da
    # requisição": ele embrulha o body num `Rack::BodyProxy` e limpa quando o
    # proxy é fechado, isto é, depois que a resposta terminou de ser enviada.
    # O `ensure` do middleware cobre apenas o caso de `@app.call` levantar, e
    # de qualquer forma a limpeza acontece no `ensure` do middleware ou no
    # fechamento do body. Isso basta para o isolamento, mas significa que o
    # Current continua valendo durante o streaming da resposta — e que o
    # RequestStore é o que garante a limpeza, não esta classe nem um
    # `around_action` nosso. Fica disponível para jobs, console e testes, que
    # não passam pelo middleware.
    def reset
      attributes.clear
    end

    def attributes
      RequestStore.store[:current] ||= {}
    end
  end
end
