class Group < ApplicationRecord
  belongs_to :session, class_name: "TournamentSession"
  has_one :selection, dependent: :destroy
  has_one :strategy, through: :selection
  has_many :match_results_as_a, class_name: "MatchResult", foreign_key: :group_a_id, dependent: :destroy
  has_many :match_results_as_b, class_name: "MatchResult", foreign_key: :group_b_id, dependent: :destroy

  has_secure_password :pin, validations: false

  validates :name, presence: true
  validates :pin_digest, presence: true

  def match_results
    MatchResult.where("group_a_id = ? OR group_b_id = ?", id, id)
  end

  def total_score
    match_results_as_a.sum(:score_a) + match_results_as_b.sum(:score_b)
  end
end
