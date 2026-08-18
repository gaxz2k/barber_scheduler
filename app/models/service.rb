class Service < ApplicationRecord
  validates :name, :duration_minutes, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  has_many :appointments
end
