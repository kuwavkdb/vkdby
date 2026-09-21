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

  test 'name ignores name_alias and falls back to person.name' do
    sp = snapshot_people(:one)
    sp.name_alias = '無視されるはずの別名'
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

  # issue #1619: extra_profile から Person新規作成用の属性への変換
  test 'extra_profile_person_attributes converts a valid MM/DD birthday to a Date with the dummy year' do
    sp = SnapshotPerson.new(extra_profile: { 'birthday' => '7/12' })

    assert_equal Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), sp.extra_profile_person_attributes[:birthday]
  end

  test 'extra_profile_person_attributes accepts a full-width slash-free variety of separators' do
    sp = SnapshotPerson.new(extra_profile: { 'birthday' => '12/25' })

    assert_equal Date.new(Person::DUMMY_BIRTH_YEAR, 12, 25), sp.extra_profile_person_attributes[:birthday]
  end

  test 'extra_profile_person_attributes skips an unparsable birthday without raising' do
    sp = SnapshotPerson.new(extra_profile: { 'birthday' => '不明' })

    assert_not sp.extra_profile_person_attributes.key?(:birthday)
  end

  test 'extra_profile_person_attributes skips an out-of-range birthday' do
    sp = SnapshotPerson.new(extra_profile: { 'birthday' => '13/40' })

    assert_not sp.extra_profile_person_attributes.key?(:birthday)
  end

  test 'extra_profile_person_attributes copies birth_year, blood, and hometown as-is' do
    sp = SnapshotPerson.new(extra_profile: { 'birth_year' => 1990, 'blood' => 'AB', 'hometown' => '東京都' })

    attrs = sp.extra_profile_person_attributes
    assert_equal 1990, attrs[:birth_year]
    assert_equal 'AB', attrs[:blood]
    assert_equal '東京都', attrs[:hometown]
  end

  test 'extra_profile_person_attributes returns an empty hash when extra_profile is blank' do
    sp = SnapshotPerson.new(extra_profile: nil)

    assert_equal({}, sp.extra_profile_person_attributes)
  end
end
