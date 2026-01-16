# == Schema Information
#
# Table name: links
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  linkable_type :string(255)      not null
#  sort_order    :integer
#  text          :string(255)
#  url           :string(255)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  linkable_id   :bigint           not null
#
# Indexes
#
#  index_links_on_linkable  (linkable_type,linkable_id)
#
require "test_helper"

class LinkTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
