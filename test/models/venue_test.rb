# frozen_string_literal: true

require 'test_helper'

class VenueTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
  def build_venue(**attrs)
    Venue.new({ key: 'shinjuku-loft', name: '新宿LOFT' }.merge(attrs))
  end

  test 'valid with key and name, defaults to live_house and active' do
    venue = build_venue

    assert venue.valid?
    assert venue.live_house?
    assert venue.active?
  end

  test 'requires key and name' do
    venue = Venue.new

    assert_not venue.valid?
    assert venue.errors.added?(:key, :blank)
    assert venue.errors.added?(:name, :blank)
  end

  test 'key is unique regardless of case' do
    build_venue.save!
    venue = build_venue(key: 'SHINJUKU-LOFT', name: '別の会場')

    assert_not venue.valid?
    assert venue.errors.of_kind?(:key, :taken)
  end

  test 'blank old_key and prefecture are normalized to nil' do
    venue = build_venue(old_key: '', prefecture: '')

    assert venue.valid?
    assert_nil venue.old_key
    assert_nil venue.prefecture
  end

  test 'prefecture must be one of PREFECTURES' do
    assert build_venue(prefecture: '東京都').valid?
    assert_not build_venue(prefecture: '東京').valid?
  end

  test 'capacity must be a positive integer when present' do
    assert build_venue(capacity: 300).valid?
    assert build_venue(capacity: nil).valid?
    assert_not build_venue(capacity: 0).valid?
    assert_not build_venue(capacity: -1).valid?
  end

  test 'name_logs_attributes= drops blank rows and keeps string keys' do
    venue = build_venue
    venue.name_logs_attributes = {
      '0' => { 'name' => '旧名', 'name_kana' => 'キュウメイ', 'date' => '2001-04' },
      '1' => { 'name' => '', 'name_kana' => '', 'date' => '' }
    }

    assert_equal [{ 'name' => '旧名', 'name_kana' => 'キュウメイ', 'date' => '2001-04' }], venue.name_log
  end

  test 'aliases_attributes= drops blank rows and casts hidden' do
    venue = build_venue
    venue.aliases_attributes = {
      '0' => { 'name' => 'ロフト', 'kana' => '', 'old_key' => '', 'hidden' => '1' },
      '1' => { 'name' => '', 'kana' => 'x' }
    }

    assert_equal [{ 'name' => 'ロフト', 'hidden' => true }], venue[:aliases]
  end

  test 'rejects name_log dates in an unknown format' do
    venue = build_venue(name_log: [{ 'name' => '旧名', 'date' => '2001年' }])

    assert_not venue.valid?
    assert venue.errors[:name_log].any?
  end

  test 'parse_name_log_date accepts year, year-month and full dates' do
    assert_equal Date.new(2001, 1, 1), Venue.parse_name_log_date('2001')
    assert_equal Date.new(2001, 4, 1), Venue.parse_name_log_date('2001-04')
    assert_equal Date.new(2001, 4, 15), Venue.parse_name_log_date('2001/4/15')
    assert_equal Date.new(2001, 4, 15), Venue.parse_name_log_date('2001.04.15')
    assert_nil Venue.parse_name_log_date('2001-13')
    assert_nil Venue.parse_name_log_date('')
  end

  test 'name_at returns the name in use on the given date' do
    venue = build_venue(
      name: 'Zepp Shinjuku',
      name_log: [
        { 'name' => 'Aホール', 'date' => '1990' },
        { 'name' => 'Bホール', 'date' => '2005-04-01' },
        { 'name' => 'Zepp Shinjuku', 'date' => '2023-04' }
      ]
    )

    assert_equal 'Aホール', venue.name_at(Date.new(1995, 6, 1))
    assert_equal 'Aホール', venue.name_at(Date.new(2005, 3, 31))
    assert_equal 'Bホール', venue.name_at(Date.new(2005, 4, 1))
    assert_equal 'Bホール', venue.name_at(Date.new(2023, 3, 31))
    assert_equal 'Zepp Shinjuku', venue.name_at(Date.new(2024, 1, 1))
  end

  test 'name_at does not depend on the order of name_log' do
    venue = build_venue(
      name: '新名',
      name_log: [{ 'name' => '新名', 'date' => '2010' }, { 'name' => '旧名', 'date' => '2000' }]
    )

    assert_equal '旧名', venue.name_at(Date.new(2005, 1, 1))
    assert_equal '新名', venue.name_at(Date.new(2015, 1, 1))
  end

  test 'name_at falls back to the current name when no history applies' do
    venue = build_venue(
      name: '現在名',
      name_log: [{ 'name' => '日付なし' }, { 'name' => '旧名', 'date' => '2000' }]
    )

    assert_equal '現在名', venue.name_at(Date.new(1999, 12, 31))
    assert_equal '現在名', venue.name_at(nil)
    assert_equal '現在名', build_venue(name: '現在名').name_at(Date.new(2020, 1, 1))
  end

  test 'name_at works with name_log assigned from the form before saving' do
    venue = build_venue(name: '新名')
    venue.name_logs_attributes = {
      '0' => { 'name' => '旧名', 'date' => '2000' },
      '1' => { 'name' => '新名', 'date' => '2010' }
    }

    assert_equal '旧名', venue.name_at(Date.new(2005, 1, 1))
  end

  test 'discard keeps the record and hides it from kept' do
    venue = build_venue
    venue.save!
    venue.discard

    assert_not_includes Venue.kept, venue
    assert_includes Venue.with_discarded, venue
  end

  test 'key cannot be changed by a normal update' do
    venue = build_venue
    venue.save!

    assert_not venue.update(key: 'renamed')
    assert venue.errors[:key].any?
  end

  test 'destination_key cannot point to itself' do
    venue = build_venue(destination_key: 'SHINJUKU-LOFT')

    assert_not venue.valid?
    assert venue.errors[:destination_key].any?
  end

  test 'change_key! changes the key and leaves a discarded redirect stub' do
    venue = build_venue(old_key: '%BF%B7%BD%C9LOFT')
    venue.save!

    venue.change_key!('loft-shinjuku')

    assert_equal 'loft-shinjuku', venue.reload.key
    assert_equal '%BF%B7%BD%C9LOFT', venue.old_key
    stub = Venue.with_discarded.find_by!(key: 'shinjuku-loft')
    assert stub.discarded?
    assert_equal 'loft-shinjuku', stub.destination_key
    assert_nil stub.old_key
    assert stub.redirect_source?
  end

  test 'change_key! does not rewrite item artist keys of a unit with the same key' do
    venue = build_venue(key: 'same-key')
    venue.save!
    item = Item.create!(title: 'CD', release_date: Date.new(2020, 1, 1), link_url: 'https://example.com/cd',
                        artists: [{ 'key' => 'same-key', 'name' => 'Unit' }])

    venue.change_key!('venue-new-key')

    assert_equal 'same-key', item.reload.artists.first['key']
  end

  test 'resolve_by_key follows destination_key chains' do
    venue = build_venue(key: 'a')
    venue.save!
    venue.change_key!('b')
    venue.change_key!('c')

    assert_equal venue, Venue.resolve_by_key('a')
    assert_equal venue, Venue.resolve_by_key('b')
    assert_equal venue, Venue.resolve_by_key('c')
    assert_nil Venue.resolve_by_key('missing')
  end

  test 'resolve_by_key returns nil for a redirect loop' do
    Venue.create!(key: 'x', name: 'X', destination_key: 'y')
    Venue.create!(key: 'y', name: 'Y', destination_key: 'x')

    assert_nil Venue.resolve_by_key('x')
  end
end
