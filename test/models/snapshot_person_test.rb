# frozen_string_literal: true

# == Schema Information
#
# Table name: snapshot_people
#
#  id               :bigint           not null, primary key
#  part             :string
#  person_name      :string
#  sort_order       :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  person_id        :bigint
#  unit_snapshot_id :bigint           not null
#
# Indexes
#
#  index_snapshot_people_on_person_id                        (person_id)
#  index_snapshot_people_on_unit_snapshot_id                 (unit_snapshot_id)
#  index_snapshot_people_on_unit_snapshot_id_and_sort_order  (unit_snapshot_id,sort_order)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_snapshot_id => unit_snapshots.id)
#
require 'test_helper'

class SnapshotPersonTest < ActiveSupport::TestCase
  test 'valid snapshot_person with person' do
    sp = snapshot_people(:one)
    assert sp.valid?
  end

  test 'valid snapshot_person with person_name only' do
    sp = snapshot_people(:three)
    assert sp.valid?
  end

  test 'requires part' do
    sp = SnapshotPerson.new(unit_snapshot: unit_snapshots(:one), person: people(:one), part: nil)
    assert_not sp.valid?
    assert sp.errors[:part].any?
  end

  test 'requires person or person_name' do
    sp = SnapshotPerson.new(unit_snapshot: unit_snapshots(:one), part: :vocal)
    assert_not sp.valid?
    assert_includes sp.errors[:base], 'Person or Person Name must be present'
  end

  test 'name returns person_name when present' do
    sp = snapshot_people(:three)
    assert_equal 'ゲストメンバー', sp.name
  end

  test 'name returns person.name when person_name is blank' do
    sp = snapshot_people(:one)
    assert_equal people(:one).name, sp.name
  end
end
