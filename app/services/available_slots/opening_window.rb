module AvailableSlots
  # O horário de funcionamento de uma unidade, para um dia.
  #
  # É a janela entre abrir e fechar, já convertido para hora local. Quando a
  # unidade não tem horário para o dia, `open?` é falso e o dia não tem slots —
  # um dia sem expediente não oferece nada, em vez de oferecer o dia inteiro.
  class OpeningWindow
    def self.for(unit)
      new(unit)
    end

    def initialize(unit)
      @unit = unit
    end

    def open?(date)
      window_for(date).present?
    end

    # Os instantes que delimitam a janela, no fuso da unidade.
    #
    # Devolve nil quando o dia não abre, para que o chamador pare em vez de
    # receber um intervalo vazio que parece válido.
    def range_for(date)
      window = window_for(date)
      return unless window

      day = date.to_date
      [ to_time(day, window[:open]), to_time(day, window[:close]) ]
    end


    # `minutes` são minutos desde a meia-noite, e não um par de hora e minuto.
    def to_time(day, minutes)
      Time.zone.local(day.year, day.month, day.day, minutes / 60, minutes % 60)
    end

    private

    attr_reader :unit

    def window_for(date)
      return @cache[date.to_date] if @cache&.key?(date.to_date)

      @cache ||= {}
      @cache[date.to_date] = build_window(date)
    end

    def build_window(date)
      config = unit&.opening_hours
      return unless config.is_a?(Hash)

      day_config = config[date.to_date.wday.to_s]
      return unless day_config.is_a?(Hash)

      open_at = parse_minutes(day_config["open"])
      close_at = parse_minutes(day_config["close"])
      return if open_at.nil? || close_at.nil?
      return if close_at <= open_at

      { open: open_at, close: close_at }
    end

    # "08:00" e "8:00" são a mesma hora. A barra é exigida porque "0800" e
    # "8:00" juntos no mesmo jsonb sugerem formato livre, e o que a pessoa
    # digita é "9:00" — sem barra, o horário seria lido como número e viraria
    # outra hora.
    def parse_minutes(value)
      return unless value.is_a?(String)

      match = value.strip.match(/\A(\d{1,2}):(\d{2})\z/)
      return unless match

      hour = match[1].to_i
      minute = match[2].to_i
      return if hour > 23 || minute > 59

      (hour * 60) + minute
    end
  end
end
