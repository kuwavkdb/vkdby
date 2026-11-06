# frozen_string_literal: true

# ニュースリリースの発信元（レーベル・事務所など）。ニュースリリースのときは必須で、動向の詳細画面に表示する（issue #2014）
class AddNewsReleaseSourceToTrends < ActiveRecord::Migration[8.1]
  def change
    add_column :trends, :news_release_source, :string
  end
end
