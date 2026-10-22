# frozen_string_literal: true

# 外部サイトの表示名。ユニット・個人のリンク欄で URL からタイトルを補完するときに使う（issue #1909）
class AddNameToExternalSites < ActiveRecord::Migration[8.1]
  def change
    add_column :external_sites, :name, :string
  end
end
