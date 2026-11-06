# frozen_string_literal: true

# ニュースリリース（情報解禁日時を厳守して公開する動向）の印（issue #2014）
class AddNewsReleaseToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :news_release, :boolean, default: false, null: false
  end
end
