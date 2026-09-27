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
end
