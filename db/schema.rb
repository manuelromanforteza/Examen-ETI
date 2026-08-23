# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_23_123438) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "pin_digest"
    t.bigint "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_groups_on_session_id"
  end

  create_table "match_results", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_a_id", null: false
    t.bigint "group_b_id", null: false
    t.text "rounds_json"
    t.integer "score_a"
    t.integer "score_b"
    t.datetime "updated_at", null: false
    t.index ["group_a_id"], name: "index_match_results_on_group_a_id"
    t.index ["group_b_id"], name: "index_match_results_on_group_b_id"
  end

  create_table "selections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.bigint "strategy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_selections_on_group_id"
    t.index ["strategy_id"], name: "index_selections_on_strategy_id"
  end

  create_table "strategies", force: :cascade do |t|
    t.text "cons"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key"
    t.string "name"
    t.text "pros"
    t.datetime "updated_at", null: false
  end

  create_table "tournament_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "rounds_per_match", default: 10, null: false
    t.string "status", default: "setup", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "groups", "tournament_sessions", column: "session_id"
  add_foreign_key "match_results", "groups", column: "group_a_id"
  add_foreign_key "match_results", "groups", column: "group_b_id"
  add_foreign_key "selections", "groups"
  add_foreign_key "selections", "strategies"
end
