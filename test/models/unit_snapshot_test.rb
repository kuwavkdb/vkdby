# frozen_string_literal: true

# == Schema Information
#
# Table name: unit_snapshots
#
#  id            :bigint           not null, primary key
#  current       :boolean          default(FALSE), not null
#  label         :string
#  snapshot_date :date             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  unit_id       :bigint           not null
#
# Indexes
#
#  index_unit_snapshots_on_unit_id                    (unit_id)
#  index_unit_snapshots_on_unit_id_and_current        (unit_id,current)
#  index_unit_snapshots_on_unit_id_and_snapshot_date  (unit_id,snapshot_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (unit_id => units.id)
#
require 'test_helper'

class UnitSnapshotTest < ActiveSupport::TestCase



  test 'same snapshot_date on different units is allowed' do
    date = unit_snapshots(:one).snapshot_date
    snapshot = UnitSnapshot.new(unit: units(:two), snapshot_date: date)
    assert snapshot.valid?
  end

  test 'display_label returns label when present' do
    snapshot = unit_snapshots(:one)
    assert_equal '結成時', snapshot.display_label
  end

  test 'display_label returns formatted date when label is blank' do
    snapshot = unit_snapshots(:two)
    assert_equal '2023/06/01', snapshot.display_label
  end

  test 'chronological scope orders by date ascending' do
    snapshots = UnitSnapshot.where(unit: units(:one)).chronological
    assert_equal unit_snapshots(:one), snapshots.first
    assert_equal unit_snapshots(:two), snapshots.last
  end

  test 'reverse_chronological scope orders by date descending' do
    snapshots = UnitSnapshot.where(unit: units(:one)).reverse_chronological
    assert_equal unit_snapshots(:two), snapshots.first
    assert_equal unit_snapshots(:one), snapshots.last
  end

  test 'destroying snapshot cascades to snapshot_people' do
    snapshot = unit_snapshots(:one)
    assert_difference 'SnapshotPerson.count', -2 do
      snapshot.destroy
    end
  end
end
