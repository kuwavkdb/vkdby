# frozen_string_literal: true

require 'test_helper'

# 会場の投稿（issue #1814）
class VenueSubmissionTest < ActiveSupport::TestCase
  setup do
    @venue = Venue.create!(key: 'shinjuku-loft', name: '新宿LOFT', prefecture: '東京都')
  end

  test 'a new venue submission requires a name and a prefecture' do
    submission = VenueSubmission.new(submission_kind: :new_venue)

    assert_not submission.valid?
    assert submission.errors[:name].any?
    assert submission.errors[:prefecture].any?
    assert VenueSubmission.new(submission_kind: :new_venue, name: '新しい会場', prefecture: '東京都').valid?
  end

  test 'a correction requires the venue and the correction' do
    submission = VenueSubmission.new(submission_kind: :correction)

    assert_not submission.valid?
    assert submission.errors[:venue].any?
    assert submission.errors[:correction].any?
    assert VenueSubmission.new(submission_kind: :correction, venue: @venue, correction: '閉店しました').valid?
  end

  test 'validates prefecture, venue type, capacity, source url and email' do
    submission = VenueSubmission.new(submission_kind: :new_venue, name: '会場', prefecture: '架空県', venue_type: 'castle',
                                     capacity: 0, source_url: 'javascript:alert(1)', email: 'not-an-email')

    assert_not submission.valid?
    %i[prefecture venue_type capacity source_url email].each do |attribute|
      assert submission.errors[attribute].any?, "#{attribute} should be invalid"
    end
  end

  test 'strips blank values' do
    submission = VenueSubmission.create!(submission_kind: :new_venue, name: ' 新しい会場 ', prefecture: '東京都', area: ' ',
                                         source_url: '')

    assert_equal '新しい会場', submission.name
    assert_nil submission.area
    assert_nil submission.source_url
  end

  test 'converts a hiragana reading to katakana' do
    submission = VenueSubmission.create!(submission_kind: :new_venue, name: '新宿LOFT', prefecture: '東京都',
                                         name_kana: 'しんじゅくろふと')

    assert_equal 'シンジュクロフト', submission.name_kana
  end

  test 'venue_attributes carries the submission into a new venue' do
    submission = VenueSubmission.new(name: '新しい会場', name_kana: 'アタラシイカイジョウ', venue_type: 'hall',
                                     prefecture: '東京都', area: '新宿', address: '東京都新宿区1-1', capacity: 300,
                                     source_url: 'https://example.com')

    venue = Venue.new(submission.venue_attributes)

    assert_equal ['新しい会場', 'アタラシイカイジョウ', 'hall', '東京都', '新宿', '東京都新宿区1-1', 300],
                 [venue.name, venue.name_kana, venue.venue_type, venue.prefecture, venue.area, venue.address, venue.capacity]
    assert_equal([%w[公式サイト https://example.com]], venue.links.map { |link| [link.text, link.url] })
  end

  test 'correctable_venue follows redirects and rejects discarded venues' do
    assert_equal @venue, VenueSubmission.correctable_venue(@venue.id)

    @venue.change_key!('loft')
    stub = Venue.with_discarded.find_by!(key: 'shinjuku-loft')
    assert_equal @venue, VenueSubmission.correctable_venue(stub.id)

    @venue.discard
    assert_nil VenueSubmission.correctable_venue(@venue.id)
    assert_nil VenueSubmission.correctable_venue(0)
  end
end
