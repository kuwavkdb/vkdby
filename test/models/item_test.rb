# frozen_string_literal: true

# == Schema Information
#
# Table name: items
#
#  id              :bigint           not null, primary key
#  artists         :jsonb            not null
#  asin            :string
#  discarded_at    :datetime
#  image_url       :string
#  link_url        :string           not null
#  release_date    :date             not null
#  title           :string           not null
#  various_artists :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  old_item_id     :integer
#
# Indexes
#
#  index_items_on_artists       (artists) USING gin
#  index_items_on_artists_trgm  (((artists)::text) gin_trgm_ops) USING gin
#  index_items_on_asin          (asin) UNIQUE
#  index_items_on_discarded_at  (discarded_at)
#  index_items_on_link_url      (link_url) UNIQUE
#  index_items_on_release_date  (release_date)
#  index_items_on_title         (title)
#  index_items_on_title_trgm    (title) USING gin
#
require 'test_helper'

class ItemTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
  test 'by_artist_old_key finds an item whose artists array contains the old_key' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-old-key',
                        artists: [{ 'name' => 'ムック', 'alias' => 'MUCC', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])
    other = Item.create!(title: 'Other Album', release_date: Date.current, link_url: 'https://example.com/item-old-key-other',
                         artists: [{ 'name' => 'Other Artist' }])

    result = Item.by_artist_old_key('%A5%E0%A5%C3%A5%AF')

    assert_includes result, item
    assert_not_includes result, other
  end

  test 'by_artist_alias finds an item whose artists array contains the alias' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-alias',
                        artists: [{ 'name' => 'ムック', 'alias' => 'MUCC' }])
    other = Item.create!(title: 'Other Album', release_date: Date.current, link_url: 'https://example.com/item-alias-other',
                         artists: [{ 'name' => 'Other Artist' }])

    result = Item.by_artist_alias('MUCC')

    assert_includes result, item
    assert_not_includes result, other
  end

  test 'replace_artist! matches by alias' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-replace-alias-match',
                        artists: [{ 'name' => 'ムック', 'alias' => 'MUCC' }])

    item.replace_artist!(match_type: 'alias', match_value: 'MUCC',
                         replacement: { 'name' => 'ムック', 'key' => 'mucc', 'alias' => 'MUCC' })

    item.reload
    assert_equal 'mucc', item.artists.first['key']
  end

  test 'replace_artist! replaces only the matching entry and marks it confirmed' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-replace',
                        artists: [
                          { 'name' => 'ムック', 'alias' => 'OLD ALIAS', 'old_key' => '%A5%E0%A5%C3%A5%AF' },
                          { 'name' => 'Other Artist', 'key' => 'other-artist' }
                        ])

    result = item.replace_artist!(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF',
                                  replacement: { 'name' => 'MUCC', 'key' => 'mucc', 'alias' => 'MUCC' })

    assert_equal true, result
    item.reload
    replaced = item.artists.find { |a| a['key'] == 'mucc' }
    untouched = item.artists.find { |a| a['key'] == 'other-artist' }

    assert_equal 'MUCC', replaced['name']
    assert_equal 'MUCC', replaced['alias']
    assert_equal true, replaced['confirmed']
    assert_nil replaced['old_key']
    assert_equal({ 'name' => 'Other Artist', 'key' => 'other-artist' }, untouched)
  end

  test 'replace_artist! clears an existing alias when the replacement does not specify one' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-replace-alias-clear',
                        artists: [{ 'name' => 'ムック', 'alias' => 'OLD ALIAS', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

    item.replace_artist!(match_type: 'old_key', match_value: '%A5%E0%A5%C3%A5%AF',
                         replacement: { 'name' => 'MUCC', 'key' => 'mucc' })

    item.reload
    assert_nil item.artists.first['alias']
  end

  test 'replace_artist! matches by key' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-replace-key',
                        artists: [{ 'name' => 'Old Name', 'key' => 'stale-key' }])

    item.replace_artist!(match_type: 'key', match_value: 'stale-key',
                         replacement: { 'name' => 'New Name', 'key' => 'new-key' })

    item.reload
    assert_equal 'new-key', item.artists.first['key']
    assert_equal 'New Name', item.artists.first['name']
  end

  test 'replace_artist! matches by name' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-replace-name',
                        artists: [{ 'name' => 'ムック' }])

    item.replace_artist!(match_type: 'name', match_value: 'ムック',
                         replacement: { 'name' => 'MUCC', 'key' => 'mucc' })

    item.reload
    assert_equal 'mucc', item.artists.first['key']
  end

  test 'replace_artist! is a no-op when nothing matches, and does not touch updated_at' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-replace-no-match',
                        artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])
    original_updated_at = item.updated_at

    result = item.replace_artist!(match_type: 'old_key', match_value: 'no-such-old-key',
                                  replacement: { 'name' => 'MUCC', 'key' => 'mucc' })

    assert_equal false, result
    item.reload
    assert_equal [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }], item.artists
    assert_equal original_updated_at, item.updated_at
  end

  test 'replace_artist! returns false for an invalid match_type' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-replace-invalid',
                        artists: [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }])

    result = item.replace_artist!(match_type: 'bogus', match_value: 'x', replacement: { 'name' => 'MUCC' })

    assert_equal false, result
    item.reload
    assert_equal [{ 'name' => 'ムック', 'old_key' => '%A5%E0%A5%C3%A5%AF' }], item.artists
  end

  test 'discard sets discarded_at and excludes the item from kept, but with_discarded still includes it' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-discard')

    item.discard

    assert item.discarded?
    assert_not_includes Item.kept, item
    assert_includes Item.discarded, item
    assert_includes Item.with_discarded, item
  end

  test 'undiscard clears discarded_at and returns the item to kept' do
    item = Item.create!(title: 'Some Album', release_date: Date.current, link_url: 'https://example.com/item-undiscard')
    item.discard

    item.undiscard

    assert_not item.discarded?
    assert_includes Item.kept, item
  end

  test 'saving an item expires today\'s new-releases sidebar cache (issue #1297)' do
    cache_key = "#{CustomPagesController::NEW_RELEASES_CACHE_KEY_PREFIX}/#{Date.current}"
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write(cache_key, %w[stale])

    Item.create!(title: 'Cache Busting Item', release_date: Date.current,
                 link_url: 'https://example.com/item-cache-bust')

    assert_nil Rails.cache.read(cache_key)
  ensure
    Rails.cache = original_cache
  end

  test 'display_link_url returns link_url unchanged when it already has the current associate tag (issue #1304)' do
    tag = Rails.application.config.amazon_associate_tag
    item = Item.create!(title: 'Some Album', release_date: Date.current,
                        link_url: "https://www.amazon.co.jp/exec/obidos/ASIN/B0EXAMPLE/#{tag}/",
                        asin: 'B0EXAMPLE')

    assert_equal item.link_url, item.display_link_url
  end

  test 'display_link_url rebuilds the URL with the current associate tag from asin when the tag is missing (issue #1304)' do
    tag = Rails.application.config.amazon_associate_tag
    item = Item.create!(title: 'Some Album', release_date: Date.current,
                        link_url: 'https://www.amazon.co.jp/dp/B0EXAMPLE',
                        asin: 'B0EXAMPLE')

    assert_equal "https://www.amazon.co.jp/exec/obidos/ASIN/B0EXAMPLE/#{tag}/", item.display_link_url
  end

  test 'display_link_url falls back to the stored link_url when asin is blank (issue #1304)' do
    item = Item.create!(title: 'Some Album', release_date: Date.current,
                        link_url: 'https://example.com/no-asin-item')

    assert_equal item.link_url, item.display_link_url
  end

  test 'discarding an item expires today\'s new-releases sidebar cache (issue #1297)' do
    item = Item.create!(title: 'Cache Busting Discard Item', release_date: Date.current,
                        link_url: 'https://example.com/item-cache-bust-discard')
    cache_key = "#{CustomPagesController::NEW_RELEASES_CACHE_KEY_PREFIX}/#{Date.current}"
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.write(cache_key, %w[stale])

    item.discard

    assert_nil Rails.cache.read(cache_key)
  ensure
    Rails.cache = original_cache
  end
end
