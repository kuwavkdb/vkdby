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

ActiveRecord::Schema[8.1].define(version: 2026_01_30_113311) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "index_groups", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "links", force: :cascade do |t|
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

  create_table "people", force: :cascade do |t|
    t.integer "birth_year"
    t.date "birthday"
    t.string "blood"
    t.datetime "created_at", null: false
    t.string "hometown"
    t.string "key"
    t.string "name"
    t.string "name_kana"
    t.jsonb "name_log"
    t.text "note"
    t.text "old_history"
    t.string "old_key"
    t.text "old_wiki_text"
    t.json "parts"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_people_on_key", unique: true
    t.index ["name"], name: "index_people_on_name"
    t.index ["name_kana"], name: "index_people_on_name_kana"
    t.index ["old_key"], name: "index_people_on_old_key", unique: true
  end

  create_table "person_logs", force: :cascade do |t|
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
    t.string "unit_url"
    t.datetime "updated_at", null: false
    t.index ["person_id", "sort_order"], name: "index_person_logs_on_person_id_and_sort_order"
    t.index ["person_id"], name: "index_person_logs_on_person_id"
    t.index ["unit_id"], name: "index_person_logs_on_unit_id"
  end

  create_table "tag_index_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "indexable_id", null: false
    t.string "indexable_type", null: false
    t.bigint "tag_index_id", null: false
    t.datetime "updated_at", null: false
    t.index ["indexable_type", "indexable_id"], name: "index_tag_index_items_on_indexable"
    t.index ["tag_index_id", "indexable_type"], name: "index_tag_index_items_on_tag_index_id_and_indexable_type"
    t.index ["tag_index_id"], name: "index_tag_index_items_on_tag_index_id"
  end

  create_table "tag_indices", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "index_group_id"
    t.string "name", null: false
    t.integer "order_in_group"
    t.datetime "updated_at", null: false
    t.index ["index_group_id", "order_in_group"], name: "index_tag_indices_on_index_group_id_and_order_in_group"
    t.index ["index_group_id"], name: "index_tag_indices_on_index_group_id"
    t.index ["name"], name: "index_tag_indices_on_name", unique: true
  end

  create_table "unit_logs", force: :cascade do |t|
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

  create_table "unit_people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "inline_history"
    t.string "old_person_key"
    t.integer "order_in_period", default: 1, null: false
    t.integer "part", default: 0, null: false
    t.integer "period", default: 1, null: false
    t.bigint "person_id"
    t.string "person_key"
    t.string "person_name"
    t.json "sns"
    t.integer "status", default: 1, null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["old_person_key"], name: "index_unit_people_on_old_person_key"
    t.index ["person_id"], name: "index_unit_people_on_person_id"
    t.index ["unit_id", "period", "order_in_period"], name: "index_unit_people_on_unit_id_and_period_and_order_in_period"
    t.index ["unit_id"], name: "index_unit_people_on_unit_id"
  end

  create_table "units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.string "name"
    t.string "name_kana"
    t.jsonb "name_log"
    t.text "note"
    t.string "old_key"
    t.text "old_wiki_text"
    t.integer "status", default: 1, null: false
    t.integer "unit_type"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_units_on_key", unique: true
    t.index ["name"], name: "index_units_on_name"
    t.index ["name_kana"], name: "index_units_on_name_kana"
    t.index ["old_key"], name: "index_units_on_old_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "wikipages", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", precision: nil, null: false
    t.integer "dw_id"
    t.integer "eplus_id"
    t.string "ip", limit: 64
    t.string "it_id", limit: 12
    t.integer "level", limit: 2, default: 0, null: false
    t.string "name", null: false
    t.string "pia_id", limit: 12
    t.string "title", limit: 100
    t.datetime "updated_at", precision: nil, null: false
    t.text "wiki"
    t.index ["name"], name: "index_wikipages_on_name", unique: true
    t.index ["wiki"], name: "index_wikipages_on_wiki_gin", opclass: :gin_trgm_ops, using: :gin
  end

  add_foreign_key "person_logs", "people"
  add_foreign_key "person_logs", "units"
  add_foreign_key "tag_index_items", "tag_indices"
  add_foreign_key "tag_indices", "index_groups"
  add_foreign_key "unit_logs", "units"
  add_foreign_key "unit_people", "people"
  add_foreign_key "unit_people", "units"
end
