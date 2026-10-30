module Appointments
  # A gaveta "Consultar meus Agendamentos" da referência SimplesAgenda: o
  # cliente digita o telefone e vê os próprios agendamentos, sem login nem
  # confirmação por SMS/e-mail — é exatamente o que a referência faz.
  #
  # O escopo de tenant protege a fronteira entre barbearias (o `Client` e o
  # `Appointment` usam `TenantScoped`, então a busca nunca atravessa para
  # outra barbearia), mas dentro da MESMA barbearia o telefone sozinho é
  # pouco: quem souber o número de alguém vê a agenda dessa pessoa. É a
  # mesma troca de privacidade que a referência faz — replicada por pedido
  # explícito — e por isso a lista devolve o mínimo necessário (sem o
  # `confirmation_token`, que daria acesso de edição ao achador do número).
  class PhoneLookup
    def self.call(...)
      new(...).call
    end

    def initialize(phone:)
      @phone = phone.to_s.gsub(/\D/, "")
    end

    def call
      return Appointment.none if @phone.blank?

      client_ids = Client.where(phone: @phone).select(:id)
      Appointment
        .where(client_id: client_ids)
        .where.not(status: :canceled)
        .order(start_at: :desc)
        .limit(MAX_RESULTS)
        .includes(:service, :professional, :client)
    end

    MAX_RESULTS = 20
  end
end
