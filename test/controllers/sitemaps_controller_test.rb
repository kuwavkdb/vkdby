# frozen_string_literal: true

require 'test_helper'

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test 'returns a urlset xml including the static pages' do
    get '/sitemap.xml'

    assert_response :success
    assert_equal 'application/xml', response.media_type

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_includes locs, root_url
    assert_includes locs, people_url
    assert_includes locs, units_url
    assert_includes locs, trends_url
    assert_includes locs, items_url
    assert_includes locs, timeline_url
    assert_includes locs, indices_groups_url
  end

  test 'includes active index groups' do
    index_group = IndexGroup.create!(name: 'Sitemap Index Group', active: true, units_filter_order: 1)

    get '/sitemap.xml'

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_includes locs, indices_group_url(index_group.id)
  end

  test 'includes published units/people but excludes unpublished and discarded ones' do
    published_unit = Unit.create!(name: 'Sitemap Published Unit', key: 'sitemap-published-unit', status: :active)
    discarded_unit = Unit.create!(name: 'Sitemap Discarded Unit', key: 'sitemap-discarded-unit', status: :active)
    discarded_unit.discard!

    unpublished_person = Person.create!(name: 'Sitemap Unpublished Person', key: 'sitemap-unpublished-person', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unpublished_person)

    get '/sitemap.xml'

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_includes locs, profile_url(published_unit.key)
    assert_not_includes locs, profile_url(discarded_unit.key)
    assert_not_includes locs, profile_url(unpublished_person.key)
  end

  test 'deduplicates the profile url when a unit and a person share the same key (existing data quirk)' do
    shared_key = "sitemap-shared-key-#{SecureRandom.hex(4)}"
    Unit.create!(name: 'Sitemap Shared Key Unit', key: shared_key, status: :active)
    Person.create!(name: 'Sitemap Shared Key Person', key: shared_key, status: :active)

    get '/sitemap.xml'

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_equal 1, locs.count(profile_url(shared_key))
  end

  test 'includes published custom pages but excludes system pages' do
    page = CustomPage.create!(key: 'sitemap-custom-page', title: 'Sitemap Custom Page', active: true)
    draft_page = CustomPage.create!(key: 'sitemap-draft-page', title: 'Sitemap Draft Page', active: false)

    get '/sitemap.xml'

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_includes locs, custom_page_url(page.key)
    assert_not_includes locs, custom_page_url(draft_page.key)
    # 'index' はroot('/')と同一ページなので二重計上しない（システムページとして除外される）
    assert_not_includes locs, custom_page_url('index')
  end

  test 'includes trends and kept items but excludes discarded items' do
    trend = Trend.create!(title: 'Sitemap Trend', date: Date.current, publish_start_at: Time.current, unit_phenomenon: :other)
    item = Item.create!(title: 'Sitemap Item', release_date: Date.current,
                        link_url: "http://example.com/sitemap-item-#{SecureRandom.hex(4)}")
    discarded_item = Item.create!(title: 'Sitemap Discarded Item', release_date: Date.current,
                                  link_url: "http://example.com/sitemap-item-discarded-#{SecureRandom.hex(4)}")
    discarded_item.discard!

    get '/sitemap.xml'

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_includes locs, trend_url(trend.id)
    assert_includes locs, item_url(item.id)
    assert_not_includes locs, item_url(discarded_item.id)
  end

  test 'includes yearly/monthly pages from 1980 onward but not earlier years' do
    get '/sitemap.xml'

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_includes locs, yearly_url(year: 1980)
    assert_includes locs, monthly_url(year: 1980, month: 1)
    assert_not_includes locs, yearly_url(year: 1979)
    assert_not_includes locs, monthly_url(year: 1979, month: 12)
  end

  test 'includes daily pages only for the last year where trend/item data exists, not for birthdays or older dates' do
    target_date = Date.current - 100.days
    Trend.create!(title: 'Sitemap daily trend', date: target_date, publish_start_at: Time.current, unit_phenomenon: :other)
    # 誕生日だけのデータではdailyページの判定に影響しないことを確認する
    # （在籍者数が多く、誕生日を判定基準に含めるとほぼ全日が対象になってしまうため）
    Person.create!(name: 'Sitemap Birthday Person', key: 'sitemap-birthday-person', status: :active,
                   birthday: Date.new(2000, target_date.month, target_date.day))

    old_date = Date.current - 400.days
    Trend.create!(title: 'Sitemap old trend', date: old_date, publish_start_at: Time.current, unit_phenomenon: :other)

    get '/sitemap.xml'

    locs = Nokogiri::XML(response.body).css('url > loc').map(&:text)
    assert_includes locs, daily_url(year: target_date.year, month: target_date.month, day: target_date.day)
    assert_not_includes locs, daily_url(year: old_date.year, month: old_date.month, day: old_date.day)
  end
end
