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

class SnapshotPersonTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
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

  # issue #1653
  test 'sns_link_attributes converts @handle to x.com url and keeps urls as-is' do
    sp = SnapshotPerson.new(sns: ['@handle', 'https://www.instagram.com/handle/'])

    assert_equal [{ url: 'https://x.com/handle', sort_order: 1 },
                  { url: 'https://www.instagram.com/handle/', sort_order: 2 }],
                 sp.sns_link_attributes
  end

  test 'sns_link_attributes skips blank, bare @, non-url values and duplicates' do
    sp = SnapshotPerson.new(sns: ['', '  ', '@', 'handle_only', '@dup', 'https://x.com/dup', ' https://example.com '])

    assert_equal [{ url: 'https://x.com/dup', sort_order: 1 },
                  { url: 'https://example.com', sort_order: 2 }],
                 sp.sns_link_attributes
  end

  test 'sns_link_attributes returns an empty array when sns is nil' do
    assert_equal [], SnapshotPerson.new(sns: nil).sns_link_attributes
  end

  test 'build_person_for_independence builds links from sns' do
    sp = SnapshotPerson.new(person_name: 'Sns Guy', person_key: 'sns_guy', part: :vocal, sns: ['@sns_guy'])

    person = sp.build_person_for_independence
    assert_equal ['https://x.com/sns_guy'], person.links.map(&:url)
  end

  # issue #1654: 既存Personへの紐付け時に sns を Person#links にマージする
  test 'merges sns into person links when linked to an existing person' do
    person = people(:one)
    person.links.create!(url: 'https://twitter.com/already/', sort_order: 5)
    sp = unit_snapshots(:one).snapshot_people.create!(
      person_name: 'Sns Guy', part: :vocal, sns: ['@already', '@new_handle', 'https://www.instagram.com/new/']
    )

    assert_difference('person.links.count', 2) do
      sp.update!(person: person)
    end

    added = person.links.where.not(url: 'https://twitter.com/already/').order(:sort_order)
    assert_equal ['https://x.com/new_handle', 'https://www.instagram.com/new/'], added.map(&:url)
    assert_equal [6, 7], added.map(&:sort_order)
    assert_equal added.to_a, sp.merged_links
  end

  test 'merges sns when linked by person_key' do
    person = people(:one)

    assert_difference('person.links.count', 1) do
      unit_snapshots(:one).snapshot_people.create!(person_key: person.key, part: :vocal, sns: ['@by_key'])
    end
    assert_equal 'https://x.com/by_key', person.links.last.url
  end

  test 'merges sns into the new person when relinked to another person' do
    sp = unit_snapshots(:one).snapshot_people.create!(person: people(:one), part: :vocal, sns: ['@relink'])

    assert_difference('people(:two).links.count', 1) do
      sp.update!(person: people(:two))
    end
    assert_equal 1, people(:one).links.count
  end

  test 'does not merge sns when person is unchanged' do
    sp = unit_snapshots(:one).snapshot_people.create!(person: people(:one), part: :vocal, sns: ['@unchanged'])
    people(:one).links.destroy_all

    assert_no_difference('Link.count') do
      sp.update!(sns: ['@unchanged', '@another'], part: :guitar)
    end
  end

  test 'does not merge sns when skip_sns_merge is set' do
    assert_no_difference('Link.count') do
      unit_snapshots(:one).snapshot_people.create!(person: people(:one), part: :vocal, sns: ['@copied'],
                                                   skip_sns_merge: true)
    end
  end

  test 'sns_urls_missing_from excludes urls already on the person and known urls' do
    person = people(:one)
    person.links.create!(url: 'https://x.com/exists')
    sp = SnapshotPerson.new(sns: ['@exists', '@planned', '@missing'])

    assert_equal ['https://x.com/missing'], sp.sns_urls_missing_from(person, known_urls: ['https://twitter.com/planned'])
  end
end
