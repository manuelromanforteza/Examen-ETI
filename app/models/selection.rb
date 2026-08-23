class Selection < ApplicationRecord
  belongs_to :group
  belongs_to :strategy

  validates :group_id, uniqueness: true
end
