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

ActiveRecord::Schema[8.1].define(version: 2026_03_08_133441) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "custom_pages", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "key", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_custom_pages_on_discarded_at"
    t.index ["key"], name: "index_custom_pages_on_key", unique: true
  end

  create_table "external_sites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "site_key", null: false
    t.datetime "updated_at", null: false
    t.string "url_pattern", null: false
    t.index ["site_key"], name: "index_external_sites_on_site_key", unique: true
  end

  create_table "index_groups", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "items", force: :cascade do |t|
    t.jsonb "artists", default: [], null: false
    t.string "asin"
    t.datetime "created_at", null: false
    t.string "image_url"
    t.string "link_url", null: false
    t.integer "old_item_id"
    t.date "release_date", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["artists"], name: "index_items_on_artists", using: :gin
    t.index ["asin"], name: "index_items_on_asin", unique: true
    t.index ["link_url"], name: "index_items_on_link_url", unique: true
    t.index ["release_date"], name: "index_items_on_release_date"
    t.index ["title"], name: "index_items_on_title"
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

  create_table "old_trends", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "hide_member"
    t.boolean "publish"
    t.datetime "publish_plan_date"
    t.text "quote"
    t.string "quote_url"
    t.boolean "rss"
    t.string "target_date"
    t.string "target_name"
    t.integer "trend_class"
    t.datetime "updated_at", null: false
    t.string "via"
    t.string "via_url"
    t.integer "wikipage_id"
  end

  create_table "people", force: :cascade do |t|
    t.jsonb "aliases", default: [], null: false
    t.integer "birth_year"
    t.date "birthday"
    t.string "blood"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "hometown"
    t.string "key"
    t.string "name"
    t.string "name_kana"
    t.jsonb "name_log"
    t.text "note"
    t.text "old_history"
    t.string "old_key"
    t.integer "old_wiki_id"
    t.text "old_wiki_text"
    t.json "parts"
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_people_on_aliases", using: :gin
    t.index ["discarded_at"], name: "index_people_on_discarded_at"
    t.index ["key"], name: "index_people_on_key", unique: true
    t.index ["name"], name: "index_people_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["name_kana"], name: "index_people_on_name_kana", opclass: :gin_trgm_ops, using: :gin
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

  create_table "release_schedules", force: :cascade do |t|
    t.text "append_after"
    t.text "append_before"
    t.string "artist", default: "", null: false
    t.string "asin"
    t.datetime "created_at"
    t.string "img_url"
    t.string "l_img_url"
    t.text "plugin_full"
    t.string "plugin_text", default: "", null: false
    t.string "product_group"
    t.string "publisher"
    t.datetime "release_date"
    t.string "title"
    t.string "tower_id"
    t.text "tracks"
    t.string "type", default: "", null: false
    t.datetime "updated_at"
    t.text "url"
    t.string "wiki"
    t.index ["asin"], name: "index_release_schedules_on_asin"
    t.index ["plugin_text"], name: "index_release_schedules_on_plugin_text", unique: true
    t.index ["wiki", "release_date"], name: "index_release_schedules_on_wiki_and_release_date"
  end

  create_table "sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.text "markdown"
    t.string "name"
    t.bigint "sectionable_id", null: false
    t.string "sectionable_type", null: false
    t.integer "sort_order"
    t.datetime "updated_at", null: false
    t.text "wiki_text"
    t.index ["discarded_at"], name: "index_sections_on_discarded_at"
    t.index ["sectionable_type", "sectionable_id"], name: "index_sections_on_sectionable"
  end

  create_table "snapshot_people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "inline_history"
    t.string "name_alias"
    t.string "old_person_key"
    t.integer "part", default: 0, null: false
    t.string "part_alias"
    t.bigint "person_id"
    t.string "person_key"
    t.string "person_name"
    t.json "sns"
    t.integer "sort_order", default: 0, null: false
    t.integer "status", default: 1, null: false
    t.boolean "support", default: false, null: false
    t.bigint "unit_snapshot_id", null: false
    t.datetime "updated_at", null: false
    t.index ["old_person_key"], name: "index_snapshot_people_on_old_person_key"
    t.index ["person_id"], name: "index_snapshot_people_on_person_id"
    t.index ["person_key"], name: "index_snapshot_people_on_person_key"
    t.index ["unit_snapshot_id", "sort_order"], name: "index_snapshot_people_on_unit_snapshot_id_and_sort_order"
    t.index ["unit_snapshot_id"], name: "index_snapshot_people_on_unit_snapshot_id"
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

  create_table "trends", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.boolean "day_unknown", default: false, null: false
    t.integer "etc_phenomenon"
    t.boolean "month_unknown", default: false, null: false
    t.integer "old_trend_id"
    t.integer "old_wiki_id"
    t.jsonb "people"
    t.integer "person_phenomenon"
    t.datetime "publish_start_at", null: false
    t.text "quote"
    t.string "quote_title"
    t.string "quote_url"
    t.date "snapshot_date"
    t.string "title"
    t.integer "unit_phenomenon"
    t.jsonb "units"
    t.datetime "updated_at", null: false
    t.string "via_name"
    t.string "via_url"
    t.index ["date"], name: "index_trends_on_date"
    t.index ["people"], name: "index_trends_on_people", using: :gin
    t.index ["units"], name: "index_trends_on_units", using: :gin
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
    t.string "part_alias"
    t.integer "period", default: 1, null: false
    t.bigint "person_id"
    t.string "person_key"
    t.string "person_name"
    t.json "sns"
    t.integer "status", default: 1, null: false
    t.boolean "support", default: false, null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["old_person_key"], name: "index_unit_people_on_old_person_key"
    t.index ["person_id"], name: "index_unit_people_on_person_id"
    t.index ["unit_id", "period", "order_in_period"], name: "index_unit_people_on_unit_id_and_period_and_order_in_period"
    t.index ["unit_id"], name: "index_unit_people_on_unit_id"
  end

  create_table "unit_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "current", default: false, null: false
    t.string "label"
    t.boolean "past", default: false, null: false
    t.date "snapshot_date"
    t.integer "snapshot_index", default: 0, null: false
    t.bigint "unit_id", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id", "current", "snapshot_index"], name: "index_unit_snapshots_on_unit_id_and_current_and_index"
    t.index ["unit_id"], name: "index_unit_snapshots_on_unit_id"
  end

  create_table "units", force: :cascade do |t|
    t.jsonb "activity_period"
    t.jsonb "aliases", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "key"
    t.string "name"
    t.string "name_kana"
    t.jsonb "name_log"
    t.text "note"
    t.string "old_key"
    t.integer "old_wiki_id"
    t.text "old_wiki_text"
    t.integer "status", default: 1, null: false
    t.integer "unit_type"
    t.datetime "updated_at", null: false
    t.index ["aliases"], name: "index_units_on_aliases", using: :gin
    t.index ["discarded_at"], name: "index_units_on_discarded_at"
    t.index ["key"], name: "index_units_on_key", unique: true
    t.index ["name"], name: "index_units_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["name_kana"], name: "index_units_on_name_kana", opclass: :gin_trgm_ops, using: :gin
    t.index ["old_key"], name: "index_units_on_old_key", unique: true
  end

  create_table "update_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "diff"
    t.bigint "loggable_id", null: false
    t.string "loggable_type", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_update_logs_on_created_at"
    t.index ["loggable_type", "loggable_id"], name: "index_update_logs_on_loggable_type_and_loggable_id"
    t.index ["user_id"], name: "index_update_logs_on_user_id"
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
  add_foreign_key "snapshot_people", "people"
  add_foreign_key "snapshot_people", "unit_snapshots"
  add_foreign_key "tag_index_items", "tag_indices"
  add_foreign_key "tag_indices", "index_groups"
  add_foreign_key "unit_logs", "units"
  add_foreign_key "unit_people", "people"
  add_foreign_key "unit_people", "units"
  add_foreign_key "unit_snapshots", "units"
  add_foreign_key "update_logs", "users"
end
