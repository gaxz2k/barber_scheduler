class Client < ApplicationRecord
  validates :phone, :name, presence: true
  has_many :appointments, dependent: :restrict_with_error
end
