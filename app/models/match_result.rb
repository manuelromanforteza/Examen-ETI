class MatchResult < ApplicationRecord
  belongs_to :group_a, class_name: "Group"
  belongs_to :group_b, class_name: "Group"

  validates :score_a, :score_b, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def rounds
    JSON.parse(rounds_json || "[]", symbolize_names: true)
  end

  def rounds=(data)
    self.rounds_json = data.to_json
  end
end
