module AppointmentsHelper
  # O rótulo de cada etapa do fluxo. Vive aqui, e não espalhado pelas views,
  # porque é o mesmo nome que aparece no título da tela e na barra de etapas —
  # e as duas coisas precisam concordar, ou o cliente lê "Escolha seu
  # profissional" logo abaixo de uma barra que o chamou de "Serviço".
  #
  # A barra diz "Profissional" e a tela diz "Profissional e horário", e não é
  # contradição: a barra nomeia a etapa, o `h1` nomeia a tela. Um cabeçalho de
  # 20 caracteres ao lado de três curtos estoura a largura no celular, e o
  # `title` do passo devolve o nome completo para quem passar o mouse.
  ROTULOS_DE_ETAPA = {
    unit: "Unidade",
    service: "Serviço",
    professional: "Profissional",
    schedule: "Horário",
    confirm: "Confirmação"
  }.freeze

  # O nome completo da etapa, usado no `title` da barra e no resumo da tela.
  # Vive separado porque a barra e o `h1` precisam de palavras diferentes: a
  # barra é um índice, o `h1` é a frase que o cliente vai ler.
  ETAPAS_COM_TITULO_COMPLETO = {
    professional: "Profissional e horário"
  }.freeze

  def titulo_da_etapa(etapa)
    ETAPAS_COM_TITULO_COMPLETO.fetch(etapa, ROTULOS_DE_ETAPA.fetch(etapa))
  end

  # A ordem canônica do fluxo, sem a unidade. A unidade entra à frente
  # quando existe — ver `booking_steps`.
  #
  # `schedule` continua na lista de rótulos mas não no fluxo: a tela de horário
  # separado só é alcançada por link antigo, com `professional` na URL. Ela
  # aparece quando a barra é desenhada para essa tela, e some no caminho normal,
  # onde quem e quando são escolhidos juntos.
  ORDEM_DO_FLUXO = %i[service professional confirm].freeze

  # A barra de etapas, em um lugar só.
  #
  # Ela existia escrita à mão em três views, e as três discordavam: a home
  # mostrava cinco etapas incluindo "Unidade", e as telas internas mostravam
  # quatro, sem ela. Quem começasse na home e avançasse veria uma barra
  # diferente em cada etapa, e nenhuma igual à anterior.
  #
  # Por que os números são calculados e não escritos: um "3" digitado à mão
  # continua "3" quando uma etapa aparece ou some. A contagem vem de
  # `index + 1` sobre a lista real, então não tem como divergir da tela.
  def booking_progress(steps)
    return if steps.blank?

    tag.div(class: "booking-progress", aria: { label: "Etapas do agendamento" }) do
      safe_join(steps.each_with_index.flat_map do |step, index|
        line = tag.span(class: "progress-line") unless index.zero?

        [ line, step_tag(step, index + 1) ].compact
      end)
    end
  end

  # Cada passo é um par de etapa e estado (`:active`, `:done` ou `:todo`).
  #
  # `aria-current="step"` marca onde o cliente está para quem usa leitor de
  # tela; sem isso a barra é uma sequência de números sem sujeito. O `title`
  # carrega o nome completo da etapa, que a barra mostra abreviado.
  def step_tag(step, position)
    etapa, state = step
    classes = [ "progress-step", ("progress-step--#{state}" if state != :done) ].compact.join(" ")
    aria = state == :active ? { current: "step" } : {}

    tag.span(class: classes, aria: aria, title: titulo_da_etapa(etapa)) do
      safe_join([ tag.b(position.to_s), tag.span(ROTULOS_DE_ETAPA.fetch(etapa)) ])
    end
  end

  # As etapas do fluxo, com o estado de cada uma.
  #
  # A lista inteira aparece, e não só até a etapa atual: o cliente precisa ver
  # o que falta, e uma barra que cresce a cada tela obriga a ler os números de
  # novo. O estado distingue o que já passou do que está em aberto — as etapas
  # à frente ficam em `:todo`, que é o terceiro estado, e é o que impede a
  # barra de tratar "ainda não cheguei" como "já resolvi".
  #
  # `com_unidade` acrescenta a etapa "Unidade" à frente. Só a home passa
  # `true`, e só quando há mais de uma loja com expediente: nas telas
  # seguintes a escolha já está feita, e repetir a etapa seria pedir a mesma
  # resposta duas vezes.
  #
  # `unidade_ativa` diz que a home está mostrando a lista de lojas. Sem a loja
  # extra a home abre direto no serviço, e o passo corrente é `:service` — não
  # `:unit`. Passar `:unit` sempre faria a barra começar em "Unidade" numa tela
  # que não tem escolha de loja, que é a divergência original em outra forma.
  def booking_steps(current, com_unidade: false, unidade_ativa: false)
    etapa_atual = com_unidade && !unidade_ativa ? :service : current
    etapas = com_unidade ? %i[unit] + ORDEM_DO_FLUXO : ORDEM_DO_FLUXO
    posicao = etapas.index(etapa_atual)
    # Uma etapa fora da lista não é erro do fluxo: `index` devolve nil e a
    # comparação quebraria com `NoMethodError` — uma tela que funciona,
    # quebrando por um passo que ninguém vê. O piso é o serviço, que é sempre
    # a primeira etapa depois da unidade. A tela de horário separado é o outro
    # caso: ela não está mais no fluxo, mas um link antigo pode trazê-la, e ela
    # é mostrada como se fosse a etapa fundida.
    atual = posicao || (etapa_atual == :schedule ? etapas.index(:professional) : etapas.index(:service))

    etapas.each_with_index.map do |etapa, index|
      estado = if index == atual
                 :active
      elsif index < atual
                 :done
      else
                 :todo
      end

      [ etapa, estado ]
    end
  end
end
