class TournamentSession < ApplicationRecord
  has_many :groups, foreign_key: :session_id, dependent: :destroy
  has_many :match_results, through: :groups

  STATUSES = %w[setup collecting running done].freeze

  validates :rounds_per_match, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
end
