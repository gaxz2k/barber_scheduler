module Scheduling
  SLOT_DURATION = 30.minutes

  def self.valid_slot?(time)
    return false if time.blank?

    time.sec.zero? && time.usec.zero? && (time.min % SLOT_DURATION.in_minutes).zero?
  end

  # Arredonda uma duração em minutos para o múltiplo de 30 minutos seguinte.
  #
  # Para cima, e não para o mais próximo: um corte de 20 min + barba de 20 min
  # soma 40, e arredondar para 30 entregaria 10 minutos a menos do que o
  # cliente escolheu. A grade só sabe oferecer blocos de 30, então o excedente
  # vira tempo de sobra do profissional, não um atraso prometido ao cliente.
  def self.round_up_to_slot(total_minutes)
    slot_minutes = SLOT_DURATION.in_minutes
    (total_minutes.to_f / slot_minutes).ceil * slot_minutes
  end
end
