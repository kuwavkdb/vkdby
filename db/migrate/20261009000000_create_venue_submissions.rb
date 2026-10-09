# frozen_string_literal: true

# ログイン不要の投稿フォームから送られる会場の情報（issue #1814）。
# 新しい会場（new_venue）と既存の会場の訂正（correction）の2種類を受け付け、管理者が確認してから反映する
class CreateVenueSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :venue_submissions do |t|
      t.integer :submission_kind, null: false, default: 0
      # 訂正の対象の会場
      t.bigint :venue_id
      # 新しい会場の情報
      t.string :name
      t.string :name_kana
      t.string :venue_type
      t.string :prefecture
      t.string :area
      t.string :address
      t.integer :capacity
      # 訂正内容
      t.text :correction
      t.string :source_url
      t.text :note
      t.string :email
      t.string :submitter_ip
      t.integer :submission_status, null: false, default: 0
      t.bigint :converted_venue_id

      t.timestamps
    end

    add_index :venue_submissions, :submission_status
    add_index :venue_submissions, :venue_id
    add_index :venue_submissions, :converted_venue_id
    add_foreign_key :venue_submissions, :venues
    add_foreign_key :venue_submissions, :venues, column: :converted_venue_id
  end
end
