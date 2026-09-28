require "vips"

module DemoShowcase
  # Imagens da galeria da vitrine, geradas em código.
  #
  # `BarbershopPhoto` valida o conteúdo com Marcel e recusa o que não for
  # PNG/JPG/WEBP, e o repositório não tem imagem de stock. Gerar aqui mantém o
  # seed autocontido: sem binário no Git, sem rede, e a vitrine funciona em
  # qualquer máquina que rode o projeto.
  #
  # São composições abstratas, não fotografias. Foto de banco pareceria
  # barbearia numa demonstração sem ser barbearia, e imagem vinda de gerador
  # externo não é reproduzível no seed. O que a vitrine precisa provar é o
  # carrossel, a legenda e o fallback de imagem quebrada — geometria cobre isso,
  # e o resultado é honesto sobre o que é.
  #
  # ruby-vips 2.3 é mais estreito do que a documentação sugere: não tem `sqrt`,
  # `mod`, `clip`, `astype` nem `Vips::Image.solid`, e as operações booleanas
  # são `&` e `|`. Tudo aqui usa apenas o que foi medido no console: `xyz`,
  # `black`, `+`, `-`, `*`, `/`, `%`, `bandjoin`, `cast`, `&`, `|` e
  # `write_to_buffer`.
  module PhotoFactory
    LARGURA = 1600
    ALTURA = 1000

    # Pares da paleta do design system: `--ink` e `--gold` (que é azul).
    PARES = [
      [ [ 11, 31, 58 ], [ 18, 58, 107 ] ],
      [ [ 18, 58, 107 ], [ 8, 102, 255 ] ],
      [ [ 7, 92, 229 ], [ 11, 31, 58 ] ],
      [ [ 28, 29, 31 ], [ 18, 58, 107 ] ],
      [ [ 8, 102, 255 ], [ 24, 24, 27 ] ],
      [ [ 11, 31, 58 ], [ 7, 92, 229 ] ]
    ].freeze

    def self.gerar(indice:)
      inicio, fim = PARES[indice % PARES.size]
      sobrepor(degradê(inicio, fim), padrao(indice), opacidade(indice)).write_to_buffer(".webp[Q=82]")
    end

    # ── Fundo ───────────────────────────────────────────────────────────────

    # Degradê diagonal. As duas frações somam no máximo 1 no canto oposto, e
    # dividir por dois mantém o valor entre 0 e 1, então nenhum canal estoura o
    # byte e nenhum recorte é preciso depois.
    def self.degradê(inicio, fim)
      x = Vips::Image.xyz(LARGURA, ALTURA).cast(:float)
      t = ((x[0] / LARGURA.to_f) + (x[1] / ALTURA.to_f)) / 2.0
      canais = [ 0, 1, 2 ].map { |b| ((t * (fim[b] - inicio[b])) + inicio[b]).cast(:uchar) }
      canais[0].bandjoin(canais[1..])
    end

    # ── Padrões ─────────────────────────────────────────────────────────────
    #
    # Seis funções distintas, uma por foto. A alternativa — um anel com raio e
    # posição variando — produzia seis imagens quase idênticas, e uma galeria
    # de seis cópias não mostra o carrossel: mostra repetição.
    #
    # Cada uma recebe as coordenadas já em float e devolve 0 ou 255. A
    # distância de um ponto ao centro é comparada ao quadrado do raio, o que
    # dispensa `sqrt`. As funções que só usam uma coordenada recebem a outra
    # com prefixo `_`.

    # 0 — anéis concêntricos, como o reflexo de um espelho
    def self.aneis(x, y)
      dx = x - (LARGURA * 0.56)
      dy = y - (ALTURA * 0.44)
      d = (dx * dx) + (dy * dy)
      # O passo é grande de propósito: com anéis finos a 1600px a imagem vira
      # um moiré quando o navegador reduz para 400px de largura, que é como o
      # carrossel mostra.
      passo = (ALTURA * 0.30) ** 2
      ((d % passo) < (passo * 0.10)).cast(:uchar)
    end

    # 1 — hachura diagonal, como o corte da navalha
    def self.hachura(x, y)
      (((x + (y * 1.6)) % (ALTURA * 0.10)) < (ALTURA * 0.026)).cast(:uchar)
    end

    # 2 — grade de pontos, como o piso de ladrilho
    def self.pontos(x, y)
      passo = ALTURA * 0.13
      dx = (x % passo) - (passo / 2)
      dy = (y % passo) - (passo / 2)
      (((dx * dx) + (dy * dy)) < ((ALTURA * 0.022) ** 2)).cast(:uchar)
    end

    # 3 — arco, a silhueta do espelho de parede
    def self.arco(x, y)
      dx = x - (LARGURA * 0.50)
      dy = y - (ALTURA * 0.30)
      d = (dx * dx) + (dy * dy)
      ((d > ((ALTURA * 0.28) ** 2)) & (d < ((ALTURA * 0.32) ** 2)) & (y < (ALTURA * 0.62))).cast(:uchar)
    end

    # 4 — faixas horizontais, como o degradê de uma luminária
    def self.faixas(_x, y)
      ((y % (ALTURA * 0.16)) < (ALTURA * 0.05)).cast(:uchar)
    end

    # 5 — curva de nível, como o corte em degradê
    def self.ondas(x, y)
      fase = ((x / LARGURA.to_f) * 6.0) + ((y / ALTURA.to_f) * 2.4)
      (((fase + 1.0) % 1.0) < 0.16).cast(:uchar)
    end

    PADROES = [ :aneis, :hachura, :pontos, :arco, :faixas, :ondas ].freeze

    def self.padrao(indice)
      x = Vips::Image.xyz(LARGURA, ALTURA).cast(:float)
      mascara = send(PADROES[indice % PADROES.size], x[0], x[1])
      # Replica o canal nas três bandas: a sobreposição soma canal a canal.
      mascara.bandjoin([ mascara, mascara ])
    end

    # A força do padrão sobe com o índice para que as seis fotos formem uma
    # progressão, e não seis repetições em intensidades diferentes.
    def self.opacidade(indice)
      0.12 + (indice * 0.03)
    end

    # ── Composição ──────────────────────────────────────────────────────────

    # `cast(:uchar)` trunca o que passar de 255 em vez de embrulhar. Uma
    # normalização por `% 256` foi tentada antes e produzia manchas verdes e
    # vermelhas no canto: o resto do ruby-vips segue o sinal do dividendo, e a
    # correção de +256 já é feita pelo cast.
    def self.sobrepor(fundo, camada, opacidade)
      (fundo.cast(:float) + (camada.cast(:float) * (opacidade * 255.0))).cast(:uchar)
    end
  end

  # Retratos dos profissionais, também gerados em código.
  #
  # São silhuetas geométricas — cabeça e ombros sobre um fundo da paleta — e
  # não rostos. Um rosto gerado por código sai com os olhos tortos, e pior que
  # isso: um rosto sintético numa vitrine que se apresenta como plataforma de
  # clientes seria uma foto de pessoa que não existe, com nome de pessoa que
  # existe. A silhueta dá o mesmo resultado visual no cartão de 44px — que é o
  # tamanho em que a foto aparece — sem inventar um rosto.
  #
  # A variação entre os profissionais vem do ângulo do degradê e do deslocamento
  # da silhueta, não de seis desenhos diferentes: no tamanho do cartão o que se
  # enxerga é a cor e a posição, e é isso que precisa variar.
  module PortraitFactory
    LADO = 512
    # O azul da paleta do design system e o azul-escuro do `--ink`. Os dois
    # valores vêm das custom properties do layout, e não de números soltos: a
    # silhueta precisa ser legível sobre o mesmo fundo do cartão.
    FONDO = [ 18, 58, 107 ].freeze
    INK = [ 11, 31, 58 ].freeze

    # O deslocamento horizontal vai de 42% a 58% da largura, o suficiente
    # para duas pessoas do mesmo time não saírem com a cabeça no mesmo
    # lugar, e pouco o bastante para nenhuma delas ficar cortada.
    def self.gerar(indice:)
      gera(0.42 + ((indice % 4) * 0.0533))
    end

    def self.gera(centro_x)
      x = Vips::Image.xyz(LADO, LADO).cast(:float)
      # A cabeça é um círculo no terço superior e os ombros um círculo largo e
      # mais baixo, cortado pela borda de baixo. Duas elipses, e não um
      # desenho: no cartão de 44px as duas viram a mesma silhueta, que é o
      # que interessa.
      #
      # Os dois círculos se sobrepõem de propósito. Com um vão entre eles a
      # cabeça fica flutuando acima dos ombros, e a silhueta deixa de parecer
      # gente — que é a única coisa que este desenho precisa parecer.
      cabeca = elipse(x, centro_x, 0.32, 0.17, 0.21)
      ombros = elipse(x, centro_x, 0.88, 0.34, 0.38)
      # A união das duas elipses é a máscara do recorte: 255 dentro da
      # silhueta, 0 fora. É multiplicada pelos canais do fundo, e não pintada
      # por cima — é isso que faz a cabeça parecer recortada do fundo em vez
      # de desenhada sobre ele.
      mascara = (cabeca | ombros).cast(:uchar)

      # O fundo é o degradê diagonal da paleta, e é o mesmo para todos: o que
      # diferencia um profissional do outro é a posição da silhueta, e um
      # fundo variado por pessoa transformaria o cartão numa colcha de retalhos.
      fundo = [ 0, 1, 2 ].map do |b|
        t = ((x[0] / LADO.to_f) * 0.35) + ((x[1] / LADO.to_f) * 0.65)
        ((t * (FONDO[b] - INK[b])) + INK[b]).cast(:uchar)
      end.reduce { |acc, canal| acc.bandjoin(canal) }

      # A cor final escolhe entre duas por pixel: o degradê onde a máscara
      # vale 255, e o azul-escuro onde vale 0. A conta é a mesma sobreposição
      # da galeria — o peso de cada cor é a própria máscara — e não há alpha
      # nem composição, porque o ruby-vips deste projeto expõe só aritmética
      # de banda. Foi exatamente esse o motivo de a primeira versão sair
      # branca: a silhueta era pintada e o resto ficava sem cor nenhuma.
      #
      # `invert` devolve o complemento da máscara, que é 255 fora da silhueta.
      inversa = mascara.invert()
      [ 0, 1, 2 ].map do |b|
        # O peso vem primeiro na multiplicação: o ruby-vips aceita escalar à
        # esquerda de imagem, e não à direita — inverter a ordem levanta
        # `Integer#*` com "Vips::Image can't be coerced into Integer".
        peso_fundo = mascara.cast(:float) / 255.0
        peso_tinta = inversa.cast(:float) / 255.0
        ((fundo[b] * peso_fundo) + (peso_tinta * INK[b])).cast(:uchar)
      end.reduce { |acc, canal| acc.bandjoin(canal) }
       .write_to_buffer(".webp[Q=88]")
    end

    def self.elipse(x, centro_x, centro_y, raio_x, raio_y)
      dx = (x[0] - (LADO * centro_x)) / (LADO * raio_x)
      dy = (x[1] - (LADO * centro_y)) / (LADO * raio_y)
      (((dx * dx) + (dy * dy)) < 1.0).cast(:uchar)
    end
  end

  # Guarda a silhueta de um profissional no Active Storage e devolve o
  # `signed_id` para a coluna `professionals.photo`.
  #
  # O `signed_id` e não o blob: a coluna é uma string, e o Active Storage
  # resolve em runtime. É o mesmo caminho de `Barbershop#logo`, e a vantagem é
  # que o upload, a validação de tipo e a variant de redimensionamento
  # continuam sendo os do Active Storage.
  #
  # A chave do blob inclui o nome da pessoa, e não o índice: reordenar a lista
  # de profissionais no seed não pode trocar a foto de quem é quem. E a
  # reexecução não duplica nada, porque o blob é procurado pela chave antes de
  # ser criado.
  def self.retrato_de(nome, indice:)
    chave = "demo/profissional-#{ActiveSupport::Digest.hexdigest(nome)}"
    blob = ActiveStorage::Blob.find_by(key: chave) ||
           ActiveStorage::Blob.create_and_upload!(
             io: StringIO.new(PortraitFactory.gerar(indice: indice)),
             filename: "profissional-#{indice + 1}.webp",
             content_type: "image/webp",
             key: chave
           )

    blob.signed_id
  end
end
