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

ActiveRecord::Schema[8.1].define(version: 2026_01_19_165343) do
  create_table "links", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.bigint "linkable_id", null: false
    t.string "linkable_type", null: false
    t.integer "sort_order"
    t.string "text"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["linkable_type", "linkable_id"], name: "index_links_on_linkable"
  end

  create_table "people", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "birth_year_unknown"
    t.date "birthday"
    t.string "blood"
    t.datetime "created_at", null: false
    t.string "hometown"
    t.string "key"
    t.string "name"
    t.string "name_kana"
    t.string "old_key"
    t.json "parts"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_people_on_key", unique: true
    t.index ["name"], name: "index_people_on_name"
    t.index ["old_key"], name: "index_people_on_old_key", unique: true
  end

  create_table "person_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "log_date"
    t.integer "log_type"
    t.string "name"
    t.integer "part"
    t.bigint "person_id", null: false
    t.integer "phenomenon", null: false
    t.string "phenomenon_alias"
    t.text "quote_text"
    t.integer "sort_order"
    t.string "source_url"
    t.text "text"
    t.bigint "unit_id"
    t.string "unit_key"
    t.string "unit_name"
    t.datetime "updated_at", null: false
    t.index ["person_id", "sort_order"], name: "index_person_logs_on_person_id_and_sort_order"
    t.index ["person_id"], name: "index_person_logs_on_person_id"
    t.index ["unit_id"], name: "index_person_logs_on_unit_id"
  end

  create_table "unit_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "log_date"
    t.integer "phenomenon"
    t.string "phenomenon_alias"
    t.text "quote_text"
    t.string "source_url"
    t.text "text"
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id"], name: "index_unit_logs_on_unit_id"
  end

  create_table "unit_people", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_in_period", default: 1, null: false
    t.integer "part", default: 0, null: false
    t.integer "period", default: 1, null: false
    t.bigint "person_id", null: false
    t.integer "status", default: 1, null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_unit_people_on_person_id"
    t.index ["unit_id", "period", "order_in_period"], name: "index_unit_people_on_unit_id_and_period_and_order_in_period"
    t.index ["unit_id"], name: "index_unit_people_on_unit_id"
  end

  create_table "units", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.string "name"
    t.string "name_kana"
    t.string "old_key"
    t.integer "status", default: 1, null: false
    t.integer "unit_type"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_units_on_key", unique: true
    t.index ["name"], name: "index_units_on_name"
    t.index ["old_key"], name: "index_units_on_old_key", unique: true
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wikipages", id: :integer, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", precision: nil
    t.integer "dw_id"
    t.integer "eplus_id"
    t.string "ip", limit: 64
    t.string "it_id", limit: 12
    t.integer "level", limit: 2, default: 0, null: false
    t.string "name", default: "", null: false, collation: "utf8mb4_bin"
    t.string "pia_id", limit: 12
    t.string "title", limit: 100
    t.datetime "updated_at", precision: nil, null: false
    t.text "wiki"
    t.index ["name"], name: "name", unique: true
    t.index ["wiki"], name: "wiki", type: :fulltext
  end

  add_foreign_key "person_logs", "people"
  add_foreign_key "person_logs", "units"
  add_foreign_key "unit_logs", "units"
  add_foreign_key "unit_people", "people"
  add_foreign_key "unit_people", "units"
end
