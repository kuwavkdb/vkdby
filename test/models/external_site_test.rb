# frozen_string_literal: true

# == Schema Information
#
# Table name: external_sites
#
#  id          :bigint           not null, primary key
#  name        :string
#  site_key    :string           not null
#  url_pattern :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_external_sites_on_site_key  (site_key) UNIQUE
#
require 'test_helper'

class ExternalSiteTest < ActiveSupport::TestCase
  test 'link_title_suggestions returns the name and url_pattern of sites with a name' do
    ExternalSite.create!(site_key: 'ameblo', name: 'Ameba Blog', url_pattern: 'https://ameblo.jp/{account}/')
    ExternalSite.create!(site_key: 'noname', url_pattern: 'https://example.com/{account}/')
    ExternalSite.create!(site_key: 'blank', name: '', url_pattern: 'https://example.org/{account}/')

    assert_equal [{ name: 'Ameba Blog', url_pattern: 'https://ameblo.jp/{account}/' }], ExternalSite.link_title_suggestions
  end

  test 'BUILTIN_LINK_TITLES rules have hosts, a title and a valid path pattern' do
    ExternalSite::BUILTIN_LINK_TITLES.each do |builtin|
      assert builtin[:service].present?
      builtin[:rules].each do |rule|
        assert rule[:hosts].present?, builtin[:service]
        assert rule[:title].present?, builtin[:service]
        assert_nothing_raised { Regexp.new(rule[:path]) } if rule[:path]
      end
    end
  end
end
