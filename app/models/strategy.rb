class Strategy < ApplicationRecord
  has_many :selections, dependent: :destroy
  has_many :groups, through: :selections

  KEYS = %w[
    tit_for_tat
    always_cooperate
    always_defect
    grudger
    tit_for_two_tats
    suspicious_tit_for_tat
    pavlov
    tester
    joss
  ].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }
  validates :name, presence: true
end
