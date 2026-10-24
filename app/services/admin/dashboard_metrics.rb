# frozen_string_literal: true

module Admin
  # Métricas agregadas do painel administrativo (ver `diagnostics-dashboard-design`).
  #
  # O SERVIDOR decide tom e texto de cada indicador — a view só pinta o que
  # recebe. Cada indicador é calculado isoladamente (`avaliar`, com rescue):
  # um erro em um cálculo nunca apaga o resto do painel.
  #
  # === Janela de tempo ===
  # Duas janelas coexistem de propósito, porque respondem perguntas diferentes:
  #
  # - Total de clientes: SEM janela — é uma contagem de cadastro (quantos
  #   clientes a barbearia já tem na carteira), não uma métrica de atividade.
  #   Limitar isso a 30 dias faria uma barbearia de 2 anos aparentar ter
  #   "zero clientes" se não agendou nada na última semana.
  # - Clientes por profissional e cancelamento: últimos `JANELA_DIAS` (30) a
  #   partir de `start_at` (data do ATENDIMENTO, não de quando foi criado o
  #   registro). É a leitura operacional: "o que aconteceu na agenda
  #   recentemente", e não "o que foi digitado no sistema recentemente" — as
  #   duas datas podem diferir bastante quando um agendamento é criado hoje
  #   para dentro de duas semanas.
  #
  # === Critério "cliente atendido por um profissional" ===
  # Um cliente conta para um profissional quando tem pelo menos um
  # agendamento NÃO CANCELADO (pending, confirmed ou completed) com aquele
  # profissional dentro da janela. `pending`/`confirmed` entram porque já
  # revelam a intenção de atendimento (a agenda está reservada); só
  # `canceled` é excluído, porque cancelado é exatamente o caso em que o
  # profissional NÃO atendeu aquele cliente.
  #
  # === Limiares de taxa de cancelamento (proporcional, nunca absoluto) ===
  # cancelados / total_no_período:
  #   >= 30%  -> critico  (quase um terço da agenda virou cancelamento)
  #   >= 15%  -> atencao  (started to hurt mas ainda não dominante)
  #   <  15%  -> ok
  #   sem nenhum agendamento no período -> sem_dado (não é "0% de
  #     cancelamento = tudo ótimo", é ausência de dado — a tela não deve
  #     fingir saúde onde não há agenda para avaliar)
  class DashboardMetrics
    JANELA_DIAS = 30

    Indicador = Struct.new(:chave, :rotulo, :valor, :tom, :detalhe, :texto, keyword_init: true)
    Resultado = Struct.new(:veredito_tom, :veredito_texto, :indicadores, :clientes_por_profissional, :janela_dias, keyword_init: true)

    # Peso de gravidade para ordenar indicadores (do mais grave ao menos
    # grave) e para escolher o motivo do veredito — mesma tabela da skill.
    PESO_TOM = { "sem_dado" => 0, "neutro" => 1, "ok" => 2, "atencao" => 3, "critico" => 4 }.freeze

    TAXA_CANCELAMENTO_CRITICO = 0.30
    TAXA_CANCELAMENTO_ATENCAO = 0.15

    def initialize(janela_dias: JANELA_DIAS)
      @janela_dias = janela_dias
      @desde = janela_dias.to_i.days.ago.beginning_of_day
    end

    def call
      indicadores = [
        avaliar(:indicador_total_clientes),
        avaliar(:indicador_taxa_cancelamento),
        avaliar(:indicador_clientes_cancelaram)
      ].compact

      indicadores.sort_by! { |item| -PESO_TOM.fetch(item.tom, 0) }

      Resultado.new(
        veredito_tom: veredito_tom(indicadores),
        veredito_texto: veredito_texto(indicadores),
        indicadores: indicadores,
        clientes_por_profissional: avaliar(:clientes_por_profissional) || [],
        janela_dias: @janela_dias
      )
    end

    private

    attr_reader :desde, :janela_dias

    # Executa um avaliador isolado: uma exceção aqui nunca derruba o painel
    # inteiro, só faz o indicador (ou a tabela) sumir desta renderização.
    def avaliar(nome)
      send(nome)
    rescue StandardError => e
      Rails.logger.error("[Admin::DashboardMetrics] falha ao avaliar #{nome}: #{e.class}: #{e.message}")
      nil
    end

    # --- Indicadores ---------------------------------------------------

    def indicador_total_clientes
      total = Client.count

      Indicador.new(
        chave: "total_clientes",
        rotulo: "Total de clientes",
        valor: total,
        tom: total.zero? ? "neutro" : "ok",
        detalhe: total.zero? ? "Nenhum cliente cadastrado ainda" : "Clientes cadastrados na carteira da barbearia",
        texto: total.to_s
      )
    end

    def indicador_taxa_cancelamento
      total = agendamentos_no_periodo.count
      cancelados = agendamentos_no_periodo.canceled.count

      if total.zero?
        return Indicador.new(
          chave: "taxa_cancelamento",
          rotulo: "Taxa de cancelamento",
          valor: nil,
          tom: "sem_dado",
          detalhe: "Nenhum agendamento nos últimos #{janela_dias} dias",
          texto: "sem dados"
        )
      end

      taxa = cancelados.to_f / total
      tom = if taxa >= TAXA_CANCELAMENTO_CRITICO
              "critico"
      elsif taxa >= TAXA_CANCELAMENTO_ATENCAO
              "atencao"
      else
              "ok"
      end

      percentual = (taxa * 100).round(1)

      Indicador.new(
        chave: "taxa_cancelamento",
        rotulo: "Taxa de cancelamento",
        valor: taxa,
        tom: tom,
        detalhe: "#{cancelados} de #{total} agendamentos cancelados nos últimos #{janela_dias} dias",
        texto: "#{formatar_percentual(percentual)}%"
      )
    end

    def indicador_clientes_cancelaram
      distintos = agendamentos_no_periodo.canceled.distinct.count(:client_id)

      Indicador.new(
        chave: "clientes_com_cancelamento",
        rotulo: "Clientes que cancelaram",
        valor: distintos,
        tom: distintos.zero? ? "ok" : "neutro",
        detalhe: distintos.zero? ? \
          "Nenhum cliente cancelou nos últimos #{janela_dias} dias" : \
          "Clientes distintos com pelo menos 1 cancelamento nos últimos #{janela_dias} dias",
        texto: distintos.to_s
      )
    end

    # --- Tabela: clientes por profissional ------------------------------

    # Quantos clientes distintos cada profissional atendeu (ver critério no
    # comentário de topo). Devolve um array de hashes, já ordenado do
    # profissional com mais clientes para o com menos — é a ordem que
    # interessa para quem olha a tela ("quem está puxando a carteira").
    def clientes_por_profissional
      contagem = agendamentos_no_periodo
                 .where.not(status: :canceled)
                 .group(:professional_id)
                 .distinct
                 .count(:client_id)

      # Todo profissional cadastrado aparece, mesmo com zero clientes no
      # período: um profissional ocioso é informação tão útil quanto um
      # concorrido — escondê-lo da tabela seria o painel decidindo o que não
      # vale a pena mostrar.
      Professional.all.map do |profissional|
        { profissional: profissional, total_clientes: contagem[profissional.id] || 0 }
      end.sort_by { |linha| -linha[:total_clientes] }
    end

    # --- Apoio -----------------------------------------------------------

    def agendamentos_no_periodo
      Appointment.where(start_at: desde..)
    end

    def formatar_percentual(valor)
      # `30.0` deve aparecer como "30", não "30.0" — só mantém a casa decimal
      # quando ela tem informação de fato (ex.: "16.7").
      valor == valor.to_i ? valor.to_i.to_s : valor.to_s
    end

    # --- Veredito ----------------------------------------------------------
    #
    # Uma frase, antes dos números, com o motivo concreto — nunca "requer
    # atenção" solto. Cita o indicador mais grave (maior peso de tom); em
    # caso de tudo "ok"/"sem_dado", a frase afirma que está tudo em ordem.

    def veredito_tom(indicadores)
      return "sem_dado" if indicadores.empty?

      pior = indicadores.max_by { |item| PESO_TOM.fetch(item.tom, 0) }
      pior.tom
    end

    def veredito_texto(indicadores)
      return "Ainda não há dados suficientes para avaliar a operação." if indicadores.empty?

      pior = indicadores.max_by { |item| PESO_TOM.fetch(item.tom, 0) }

      case pior.tom
      when "critico", "atencao"
        "Atenção: #{pior.rotulo.downcase} — #{pior.detalhe}."
      when "sem_dado"
        "Ainda não há agendamentos suficientes no período para avaliar a operação."
      else
        "Tudo em ordem nos últimos #{janela_dias} dias."
      end
    end
  end
end
