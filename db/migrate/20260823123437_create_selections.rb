class CreateSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :selections do |t|
      t.references :group, null: false, foreign_key: true
      t.references :strategy, null: false, foreign_key: true

      t.timestamps
    end
  end
end
