# frozen_string_literal: true

# Trendに会場（Venue）を紐付ける（issue #1685, #1689）。1件のTrendにつき会場は1件のみ。
# venue_nameは表示名の上書き用で、未設定なら会場のname_logからTrendの日付時点の名前を引く。
class AddVenueToTrends < ActiveRecord::Migration[8.1]
  def change
    add_reference :trends, :venue, foreign_key: true, null: true
    add_column :trends, :venue_name, :string
  end
end
