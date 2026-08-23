class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.references :session, null: false, foreign_key: { to_table: :tournament_sessions }
      t.string :name
      t.string :pin_digest

      t.timestamps
    end
  end
end
