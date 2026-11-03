# frozen_string_literal: true

require 'test_helper'

class UnitSnapshotsComponentTest < ActionView::TestCase
  include ViewComponent::TestHelpers

  setup do
    @unit = Unit.create!(name: 'Filter Unit', key: 'unit-member-filter', status: :active)
    @snapshot = @unit.unit_snapshots.create!(snapshot_date: Date.current, current: true)
  end

  test 'shows the member filter when a snapshot has more than 10 members (issue #1999)' do
    add_members(11)

    render_inline(UnitSnapshotsComponent.new(snapshots: @unit.unit_snapshots, unit: @unit))

    assert_selector 'section[data-controller="toggle member-filter"]'
    assert_selector "input#member-filter-#{@snapshot.id}[type=search]", visible: :all
  end

  test 'hides the member filter when a snapshot has 10 members or fewer (issue #1999)' do
    add_members(10)

    render_inline(UnitSnapshotsComponent.new(snapshots: @unit.unit_snapshots, unit: @unit))

    assert_selector 'section[data-controller="toggle"]'
    assert_no_selector 'input[type=search]', visible: :all
  end

  test 'hides the member filter in the {{snapshot}} plugin (issue #1999)' do
    add_members(11)

    render_inline(UnitSnapshotsComponent.new(snapshots: @unit.unit_snapshots, unit: @unit, summary_preview: false))

    assert_no_selector 'input[type=search]', visible: :all
  end

  private

  def add_members(count)
    count.times { |i| @snapshot.snapshot_people.create!(person_name: "メンバー#{i}", part: :vocal, sort_order: i) }
  end
end
