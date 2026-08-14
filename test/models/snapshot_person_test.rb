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
  include ActiveSupport::Testing::TimeHelpers

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

  # {{snapshot}}プラグイン（application_helper.rb）のキャッシュキーは
  # UnitSnapshot#updated_at を参照しているため、SnapshotPersonの作成・更新・削除で
  # 親UnitSnapshotのupdated_atも更新される（touch: true）必要がある。
  test '作成時に親unit_snapshotのupdated_atをtouchする' do
    snapshot = unit_snapshots(:one)
    original_updated_at = snapshot.updated_at

    travel_to(original_updated_at + 1.minute) do
      snapshot.snapshot_people.create!(person_name: 'タッチテスト', part: :vocal, status: :active)
    end

    assert_not_equal original_updated_at, snapshot.reload.updated_at
  end

  test '更新時に親unit_snapshotのupdated_atをtouchする' do
    sp = snapshot_people(:one)
    snapshot = sp.unit_snapshot
    original_updated_at = snapshot.updated_at

    travel_to(original_updated_at + 1.minute) do
      sp.update!(person_name: '更新後の名前')
    end

    assert_not_equal original_updated_at, snapshot.reload.updated_at
  end

  test '削除時に親unit_snapshotのupdated_atをtouchする' do
    sp = snapshot_people(:one)
    snapshot = sp.unit_snapshot
    original_updated_at = snapshot.updated_at

    travel_to(original_updated_at + 1.minute) do
      sp.destroy!
    end

    assert_not_equal original_updated_at, snapshot.reload.updated_at
  end
end
