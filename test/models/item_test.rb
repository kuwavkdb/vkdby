# == Schema Information
#
# Table name: items
#
#  id           :bigint           not null, primary key
#  artists      :jsonb            not null
#  asin         :string
#  image_url    :string
#  link_url     :string           not null
#  release_date :date             not null
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  old_item_id  :integer
#
# Indexes
#
#  index_items_on_artists       (artists) USING gin
#  index_items_on_link_url      (link_url) UNIQUE
#  index_items_on_release_date  (release_date)
#  index_items_on_title         (title)
#
require "test_helper"

class ItemTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
