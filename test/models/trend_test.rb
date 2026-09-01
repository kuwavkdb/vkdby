# frozen_string_literal: true

# == Schema Information
#
# Table name: trends
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  content           :text
#  date              :date             not null
#  day_unknown       :boolean          default(FALSE), not null
#  etc_phenomenon    :integer
#  month_unknown     :boolean          default(FALSE), not null
#  people            :jsonb
#  person_phenomenon :integer
#  publish_start_at  :datetime         not null
#  quote             :text
#  quote_title       :string
#  quote_url         :string
#  title             :string
#  unit_phenomenon   :integer
#  units             :jsonb
#  via_name          :string
#  via_url           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  old_trend_id      :integer
#  old_wiki_id       :integer
#
# Indexes
#
#  index_trends_on_date    (date)
#  index_trends_on_people  (people) USING gin
#  index_trends_on_units   (units) USING gin
#
require 'test_helper'

class TrendTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # test "the truth" do
  #   assert true
  # end

  test 'title_without_trailing_parenthetical strips a trailing half-width parenthetical' do
    trend = Trend.new(title: '無期限活動休止(Shibuya Spotify O-EAST)')

    assert_equal '無期限活動休止', trend.title_without_trailing_parenthetical
  end

  test 'title_without_trailing_parenthetical leaves a title without a trailing parenthetical unchanged' do
    trend = Trend.new(title: '無期限活動休止')

    assert_equal '無期限活動休止', trend.title_without_trailing_parenthetical
  end

  test 'ogp_image_relative_url composes the OGP banner as unit/person names, title and date on separate lines' do
    unit = Unit.create!(name: 'Banner Unit', key: 'trend-ogp-unit', status: :active)
    person = Person.create!(name: 'Banner Person', key: 'trend-ogp-person', status: :active)
    trend = Trend.create!(title: 'Banner Trend(Some Venue)', date: '2026-05-01', publish_start_at: Time.current,
                          unit_phenomenon: :other, person_phenomenon: :other,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Banner Unit' }],
                          people: [{ 'person_id' => person.id, 'name' => 'Banner Person' }])

    generated_text = nil
    generator = lambda { |text|
      generated_text = text
      'dummy-png-bytes'
    }

    stub_class_method(OgpImageGenerator, :call, generator) { trend.ogp_image_relative_url }

    assert_equal "Banner Unit Banner Person\nBanner Trend\n2026/05/01", generated_text
    assert trend.ogp_image.attached?
  end

  test 'ogp_image_relative_url excludes the person name from the banner when person_phenomenon is not set' do
    unit = Unit.create!(name: 'Unit Only Banner Unit', key: 'trend-ogp-unit-only', status: :active)
    person = Person.create!(name: 'Unlisted Banner Person', key: 'trend-ogp-unlisted-person', status: :active)
    trend = Trend.create!(title: 'Unit Only Banner Trend', date: '2026-05-01', publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Unit Only Banner Unit' }],
                          people: [{ 'person_id' => person.id, 'name' => 'Unlisted Banner Person' }])

    generated_text = nil
    generator = lambda { |text|
      generated_text = text
      'dummy-png-bytes'
    }

    stub_class_method(OgpImageGenerator, :call, generator) { trend.ogp_image_relative_url }

    assert_equal "Unit Only Banner Unit\nUnit Only Banner Trend\n2026/05/01", generated_text
  end

  test 'updating the title purges the previously generated ogp_image so it regenerates next time' do
    trend = Trend.create!(title: 'Old Title', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other)
    stub_class_method(OgpImageGenerator, :call, 'dummy-png-bytes') { trend.ogp_image_relative_url }
    assert trend.ogp_image.attached?

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      trend.update!(title: 'New Title')
    end
  end

  test 'updating units purges the previously generated ogp_image so it regenerates next time' do
    unit = Unit.create!(name: 'Purge Unit', key: 'trend-ogp-purge-unit', status: :active)
    trend = Trend.create!(title: 'Purge Title', date: Date.current, publish_start_at: Time.current,
                          etc_phenomenon: :other)
    stub_class_method(OgpImageGenerator, :call, 'dummy-png-bytes') { trend.ogp_image_relative_url }
    assert trend.ogp_image.attached?

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      trend.update!(units: [{ 'unit_id' => unit.id, 'name' => 'Purge Unit' }], unit_phenomenon: :other)
    end
  end

  test 'updating the date purges the previously generated ogp_image so it regenerates next time' do
    trend = Trend.create!(title: 'Purge Date Title', date: '2026-05-01', publish_start_at: Time.current,
                          etc_phenomenon: :other)
    stub_class_method(OgpImageGenerator, :call, 'dummy-png-bytes') { trend.ogp_image_relative_url }
    assert trend.ogp_image.attached?

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      trend.update!(date: '2026-05-02')
    end
  end
end
