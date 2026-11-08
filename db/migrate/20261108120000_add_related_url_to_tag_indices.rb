# frozen_string_literal: true

# タグの関連ページ（サイト内パス）と、タグページからそこへ転送するかどうかのフラグ（issue #2027）
class AddRelatedUrlToTagIndices < ActiveRecord::Migration[8.1]
  def change
    add_column :tag_indices, :related_url, :string
    add_column :tag_indices, :redirect_to_related_url, :boolean, default: false, null: false
  end
end
