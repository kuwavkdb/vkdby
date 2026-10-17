# frozen_string_literal: true

# ログイン不要の投稿フォームから送られる、既存のユニット・個人の情報の訂正（issue #1902）。
# 管理者が内容を確認し、対象を編集して反映したら対応済みにする
class CreateProfileCorrections < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_corrections do |t|
      # 訂正の対象（Unit または Person）
      t.references :target, polymorphic: true, null: false
      t.text :correction, null: false
      t.string :source_url
      t.text :note
      t.string :email
      t.string :submitter_ip
      t.integer :submission_status, null: false, default: 0

      t.timestamps
    end

    add_index :profile_corrections, :submission_status
  end
end
