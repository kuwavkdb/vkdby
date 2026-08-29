# frozen_string_literal: true

require 'test_helper'

class UnitGraphBuilderTest < ActiveSupport::TestCase
  test 'excludes a discarded unit sharing a current member from the graph nodes' do
    person = Person.create!(name: 'Shared Member', key: 'graph-shared-member', status: :active)
    unit_a = Unit.create!(name: 'Center Unit', key: 'graph-center-unit', status: :active)
    unit_b = Unit.create!(name: 'Discarded Related Unit', key: 'graph-discarded-unit', status: :active)

    snapshot_a = unit_a.unit_snapshots.create!(snapshot_date: Date.new(2026, 1, 1), current: true)
    snapshot_a.snapshot_people.create!(person:, sort_order: 1)

    snapshot_b = unit_b.unit_snapshots.create!(snapshot_date: Date.new(2026, 1, 1), current: true)
    snapshot_b.snapshot_people.create!(person:, sort_order: 1)

    unit_b.discard

    result = UnitGraphBuilder.new(unit_a).call
    node_ids = result[:nodes].map { |node| node[:data][:id] }

    assert_not_includes node_ids, "unit_#{unit_b.id}"
  end
end
