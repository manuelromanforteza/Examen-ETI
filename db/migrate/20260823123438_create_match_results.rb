class CreateMatchResults < ActiveRecord::Migration[8.1]
  def change
    create_table :match_results do |t|
      t.references :group_a, null: false, foreign_key: { to_table: :groups }
      t.references :group_b, null: false, foreign_key: { to_table: :groups }
      t.text :rounds_json
      t.integer :score_a
      t.integer :score_b

      t.timestamps
    end
  end
end
