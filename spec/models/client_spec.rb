require "rails_helper"

RSpec.describe Client, type: :model do
  it "is a valid client" do
    client = described_class.new(phone: "123-456-7890", name: "John Doe")
    expect(client).to be_valid
  end

  it "is invalid without a phone number" do
    client = described_class.new(phone: nil)
    expect(client).not_to be_valid
  end

  it "is invalid without a name" do
    client = described_class.new(name: nil)
    expect(client).not_to be_valid
  end

  it "filters personal data out of the SQL log" do
    result = described_class.filter_attributes.map(&:to_s)

    expect(result).to include("name", "phone")
  end

  describe "#masked_phone" do
    # A página de confirmação é acessada por link e mostra o telefone do
    # cliente. Nome e telefone completos são PII desnecessária ali; o cliente se
    # reconhece pelos últimos dígitos.
    it "preserva apenas os quatro ultimos digitos" do
      expect(described_class.new(phone: "(11) 98765-4321").masked_phone).to eq("*******4321")
    end

    it "conta os digitos, nao os caracteres de formatacao" do
      expect(described_class.new(phone: "11987654321").masked_phone).to eq("*******4321")
    end

    it "devolve o telefone intacto quando ha menos de quatro digitos" do
      expect(described_class.new(phone: "123").masked_phone).to eq("123")
    end

    it "nao estoura quando o telefone e vazio" do
      expect(described_class.new(phone: nil).masked_phone).to be_nil
    end
  end
end
