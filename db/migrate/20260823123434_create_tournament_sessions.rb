class CreateTournamentSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_sessions do |t|
      t.integer :rounds_per_match, null: false, default: 10
      t.string :status, null: false, default: "setup"

      t.timestamps
    end
  end
end
