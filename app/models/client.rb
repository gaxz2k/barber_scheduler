class Client < ApplicationRecord
  validates :phone, :name, presence: true
  has_many :appointments
end
