# frozen_string_literal: true

# 表記ゆれを吸収した検索のための search_text 列（issue #1842）。中身は SearchTextable が
# 保存時に作る。既存のレコードはここで作っておく。
class AddSearchTextToUnitsPeopleAndVenues < ActiveRecord::Migration[8.1]
  TABLES = %i[units people venues].freeze

  def up
    TABLES.each { |table| add_column table, :search_text, :text }
    [Unit, Person, Venue].each do |model|
      model.reset_column_information
      model.rebuild_search_text!
    end
  end

  def down
    TABLES.each { |table| remove_column table, :search_text }
  end
end
