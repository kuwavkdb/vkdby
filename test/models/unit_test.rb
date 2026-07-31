# frozen_string_literal: true

# == Schema Information
#
# Table name: units
#
#  id            :bigint           not null, primary key
#  key           :string
#  name          :string
#  name_kana     :string
#  name_log      :jsonb
#  note          :text
#  old_key       :string
#  old_wiki_text :text
#  status        :integer          default("active"), not null
#  unit_type     :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  old_wiki_id   :integer
#
# Indexes
#
#  index_units_on_key        (key) UNIQUE
#  index_units_on_name       (name)
#  index_units_on_name_kana  (name_kana)
#  index_units_on_old_key    (old_key) UNIQUE
#
require 'test_helper'

class UnitTest < ActiveSupport::TestCase
  test 'key can be set on create' do
    unit = Unit.create!(name: 'New Unit', key: 'new-unit-key-test', status: :active)

    assert_equal 'new-unit-key-test', unit.key
  end

  test 'key cannot be changed once set' do
    unit = Unit.create!(name: 'Existing Unit', key: 'existing-unit-key-test', status: :active)

    unit.key = 'changed-unit-key-test'

    assert_not unit.valid?
    assert_includes unit.errors[:key], 'cannot be changed once set'
  end

  test 'key uniqueness is case-insensitive' do
    Unit.create!(name: 'Existing Unit', key: 'case-key-test', status: :active)
    unit = Unit.new(name: 'Duplicate Unit', key: 'Case-Key-Test', status: :active)

    assert_not unit.valid?
    assert_includes unit.errors[:key], 'はすでに存在します'
  end

  test 'change_key! raises when new key duplicates an existing key by case only' do
    Unit.create!(name: 'Existing Unit', key: 'case-change-target', status: :active)
    unit = Unit.create!(name: 'Renaming Unit', key: 'unit-key-change-case-before', status: :active)

    assert_raises(ActiveRecord::RecordInvalid) do
      unit.change_key!('Case-Change-Target')
    end
  end

  test 'change_key! raises when new key duplicates a discarded redirect stub by case only' do
    unit = Unit.create!(name: 'Rename Target Unit', key: 'unit-key-stub-before', status: :active)
    unit.change_key!('unit-key-stub-after')
    other = Unit.create!(name: 'Other Unit', key: 'unit-key-stub-other', status: :active)

    assert_raises(ActiveRecord::RecordInvalid) do
      other.change_key!('Unit-Key-Stub-Before')
    end
  end

  test 'other attributes can still be updated when key is unchanged' do
    unit = Unit.create!(name: 'Existing Unit', key: 'unchanged-unit-key-test', status: :active)

    assert unit.update(name: 'Renamed Unit')
    assert_equal 'Renamed Unit', unit.reload.name
  end

  test 'change_key! updates the key and creates a discarded redirect stub' do
    unit = Unit.create!(name: 'Rename Target Unit', key: 'unit-key-change-before', status: :active)

    unit.change_key!('unit-key-change-after')

    assert_equal 'unit-key-change-after', unit.reload.key

    stub = Unit.discarded.find_by(key: 'unit-key-change-before')
    assert stub.present?
    assert stub.discarded?
    assert_equal 'unit-key-change-after', stub.destination_key
    assert_nil stub.old_key
  end

  test 'change_key! rewrites items.artists referencing the previous key' do
    unit = Unit.create!(name: 'Artist Unit', key: 'unit-artist-key-before', status: :active)
    item = Item.create!(title: 'Artist Item', release_date: Date.current, link_url: 'https://example.com/unit-artist-item',
                        artists: [{ 'name' => 'Artist Unit', 'key' => 'unit-artist-key-before' }])

    unit.change_key!('unit-artist-key-after')

    assert_equal 'unit-artist-key-after', item.reload.artists.first['key']
  end

  test 'unpublished? is false without an unpublished tag' do
    unit = Unit.create!(name: 'Untagged Unit', key: 'unit-untagged', status: :active)

    assert_not unit.unpublished?
  end

  test 'unpublished? is true when tagged with a configured unpublished tag id' do
    unit = Unit.create!(name: 'Unpublished Unit', key: 'unit-unpublished', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unit)

    assert unit.unpublished?
  end

  test 'published scope excludes units tagged with a configured unpublished tag id' do
    published_unit = Unit.create!(name: 'Published Unit', key: 'unit-published-scope', status: :active)
    unpublished_unit = Unit.create!(name: 'Unpublished Unit', key: 'unit-unpublished-scope', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unpublished_unit)

    assert_includes Unit.published, published_unit
    assert_not_includes Unit.published, unpublished_unit
  end
end
