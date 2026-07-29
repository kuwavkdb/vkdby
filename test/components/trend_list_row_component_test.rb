# frozen_string_literal: true

require 'test_helper'

class TrendListRowComponentTest < ActiveSupport::TestCase
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

  test 'unit_badges always includes a different unit referenced by the trend' do
    resource_unit = Unit.create!(name: 'Resource Unit', key: 'trend-row-multi-resource', status: :active)
    other_unit = Unit.create!(name: 'Other Unit', key: 'trend-row-multi-other', status: :active)
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => resource_unit.id, 'name' => 'Resource Unit' },
                                  { 'unit_id' => other_unit.id, 'name' => 'Other Unit' }])

    component = TrendListRowComponent.new(trend: trend, resource: resource_unit,
                                          related_units: { resource_unit.id => resource_unit,
                                                           other_unit.id => other_unit })

    assert_equal ['Other Unit'], component.unit_badges
  end

  test 'unit_badges omits an entry for a discarded unit with no recorded name' do
    unit = Unit.create!(name: 'Discarded Badge Unit', key: 'trend-row-discarded', status: :active)
    resource_unit = Unit.create!(name: 'Resource Unit 2', key: 'trend-row-discarded-resource', status: :active)
    unit.discard
    trend = Trend.create!(title: 'Trend', date: Date.current, publish_start_at: Time.current,
                          unit_phenomenon: :other,
                          units: [{ 'unit_id' => resource_unit.id, 'name' => 'Resource Unit 2' },
                                  { 'unit_id' => unit.id }])

    component = TrendListRowComponent.new(trend: trend, resource: resource_unit,
                                          related_units: { resource_unit.id => resource_unit })

    assert_empty component.unit_badges
  end
end
