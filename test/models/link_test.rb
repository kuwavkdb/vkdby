# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  linkable_type :string           not null
#  sort_order    :integer
#  text          :string
#  url           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  linkable_id   :bigint           not null
#
# Indexes
#
#  index_links_on_linkable  (linkable_type,linkable_id)
#
require 'test_helper'

class LinkTest < ActiveSupport::TestCase
  test 'twitter_status_url? is true for a twitter.com status URL' do
    link = Link.new(url: 'https://twitter.com/nonameactorsjp/status/892008297930268674')

    assert link.twitter_status_url?
  end

  test 'twitter_status_url? is true for an x.com status URL' do
    link = Link.new(url: 'https://x.com/nonameactorsjp/status/892008297930268674')

    assert link.twitter_status_url?
  end

  test 'twitter_status_url? is false for a plain twitter.com profile URL' do
    link = Link.new(url: 'https://twitter.com/nonameactorsjp')

    refute link.twitter_status_url?
  end

  test 'twitter_status_url? is false for a blank URL' do
    link = Link.new(url: nil)

    refute link.twitter_status_url?
  end
end
