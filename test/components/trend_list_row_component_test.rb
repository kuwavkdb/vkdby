# frozen_string_literal: true

require 'test_helper'

class TrendListRowComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  test 'unit_badges is empty when resource is not given' do
    unit = Unit.create!(name: 'No Resource Unit', key: 'trend-row-no-resource', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Old Name' }])

    component = TrendListRowComponent.new(trend: trend)

    assert_empty component.unit_badges
  end

  test 'unit_badges omits an entry that matches the current resource name' do
    unit = Unit.create!(name: 'Same Name Unit', key: 'trend-row-same-name', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Same Name Unit' }])

    component = TrendListRowComponent.new(trend: trend, resource: unit, related_units: { unit.id => unit })

    assert_empty component.unit_badges
  end

  test 'unit_badges includes an entry recorded under a name different from the current resource name' do
    unit = Unit.create!(name: 'Renamed Now', key: 'trend-row-diff-name', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Old Name' }])

    component = TrendListRowComponent.new(trend: trend, resource: unit, related_units: { unit.id => unit })

    assert_equal ['Old Name'], component.unit_badges
  end

  test 'unit_badges does not include a different unit referenced by the trend' do
    resource_unit = Unit.create!(name: 'Resource Unit', key: 'trend-row-multi-resource', status: :active)
    other_unit = Unit.create!(name: 'Other Unit', key: 'trend-row-multi-other', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => resource_unit.id, 'name' => 'Resource Unit' },
                                  { 'unit_id' => other_unit.id, 'name' => 'Other Unit' }])

    component = TrendListRowComponent.new(trend: trend, resource: resource_unit,
                                          related_units: { resource_unit.id => resource_unit,
                                                           other_unit.id => other_unit })

    assert_empty component.unit_badges
  end

  test 'unit_badges includes the resource alias even when another unit is also referenced' do
    resource_unit = Unit.create!(name: 'Renamed Now', key: 'trend-row-multi-alias', status: :active)
    other_unit = Unit.create!(name: 'Other Unit', key: 'trend-row-multi-alias-other', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => resource_unit.id, 'name' => 'Old Name' },
                                  { 'unit_id' => other_unit.id, 'name' => 'Other Unit' }])

    component = TrendListRowComponent.new(trend: trend, resource: resource_unit,
                                          related_units: { resource_unit.id => resource_unit,
                                                           other_unit.id => other_unit })

    assert_equal ['Old Name'], component.unit_badges
  end

  test 'renders the date only as far as it is known (issue #1917)' do
    trend = Trend.create!(title: 'Day unknown row', date: Date.new(2020, 12, 1), publish_start_at: Time.current,
                          unit_phenomenon: :other, day_unknown: true)

    text = render_inline(TrendListRowComponent.new(trend: trend)).text

    assert_includes text, '2020/12'
    assert_not_includes text, '2020/12/01'
  end

  test 'marks an unpublished trend with a dashed border and screen reader text' do
    trend = Trend.create!(title: 'Scheduled Trend', date: Date.current, publish_start_at: 1.day.from_now,
                          unit_phenomenon: :other)

    render_inline(TrendListRowComponent.new(trend: trend))

    assert_selector 'div.border-dashed'
    assert_selector '.sr-only', text: '（未公開）'
  end

  test 'does not mark a published trend' do
    trend = Trend.create!(title: 'Published Trend', date: Date.current, publish_start_at: 1.minute.ago,
                          unit_phenomenon: :other)

    render_inline(TrendListRowComponent.new(trend: trend))

    assert_no_selector 'div.border-dashed'
    assert_no_selector '.sr-only', text: '（未公開）'
  end

  # issue #2092: 個人名を件名前に優先表示する動向は、ユニット名の代わりに個人名を出す（個人のページでは本人の名前も）
  test 'lead_badges shows person names instead of unit badges when person_name_in_title is set' do
    unit = Unit.create!(name: 'Renamed Now', key: 'trend-row-person-priority-unit', status: :active)
    person = Person.create!(name: '個人A', key: 'trend-row-person-priority', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, person_name_in_title: true,
                          units: [{ 'unit_id' => unit.id, 'name' => 'Old Name' }],
                          people: [{ 'person_id' => person.id, 'name' => '個人A' }])

    on_unit_page = TrendListRowComponent.new(trend: trend, resource: unit, related_units: { unit.id => unit },
                                             related_people: { person.id => person })
    on_person_page = TrendListRowComponent.new(trend: trend, resource: person, related_people: { person.id => person })

    assert_equal ['個人A'], on_unit_page.lead_badges
    assert_equal ['個人A'], on_person_page.lead_badges
  end

  test 'lead_badges falls back to unit_badges for a normal trend' do
    unit = Unit.create!(name: 'Renamed Now', key: 'trend-row-normal-unit', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Old Name' }])

    assert_equal ['Old Name'], TrendListRowComponent.new(trend: trend, resource: unit, related_units: { unit.id => unit }).lead_badges
  end
end
