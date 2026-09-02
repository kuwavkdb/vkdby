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
  include ActiveJob::TestHelper

  test 'key is required on create' do
    unit = Unit.new(name: 'No Key Unit', status: :active)

    assert_not unit.save
    assert_includes unit.errors[:key], 'を入力してください'
  end

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

  test 'ogp_image_relative_url generates and attaches an image on first call (issue #1259)' do
    unit = Unit.create!(name: 'First Call Unit', key: 'unit-ogp-first', status: :active)

    result = stub_class_method(OgpImageGenerator, :call, 'dummy-png-bytes') { unit.ogp_image_relative_url }

    assert unit.ogp_image.attached?
    assert_match %r{\A/rails/active_storage/}, result
  end

  test 'ogp_image_relative_url reuses the previously generated image without regenerating' do
    unit = Unit.create!(name: 'Reuse Unit', key: 'unit-ogp-reuse', status: :active)
    call_count = 0
    generator = lambda { |_name|
      call_count += 1
      'dummy-png-bytes'
    }

    stub_class_method(OgpImageGenerator, :call, generator) do
      unit.ogp_image_relative_url
      unit.ogp_image_relative_url
    end

    assert_equal 1, call_count
  end

  test 'ogp_image_relative_url returns nil and attaches nothing when the generator returns nil' do
    unit = Unit.create!(name: 'No Vips Unit', key: 'unit-ogp-no-vips', status: :active)

    result = stub_class_method(OgpImageGenerator, :call, nil) { unit.ogp_image_relative_url }

    assert_nil result
    assert_not unit.ogp_image.attached?
  end

  test 'updating name purges the previously generated ogp_image so it regenerates next time' do
    unit = Unit.create!(name: 'Old Name Unit', key: 'unit-ogp-purge', status: :active)
    stub_class_method(OgpImageGenerator, :call, 'dummy-png-bytes') { unit.ogp_image_relative_url }
    assert unit.ogp_image.attached?

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      unit.update!(name: 'New Name Unit')
    end
  end

  test 'with_attached_ogp_image avoids an N+1 query when checking attached? (issue #1267)' do
    unit = Unit.create!(name: 'Eager Load Unit', key: 'unit-ogp-eager', status: :active)
    stub_class_method(OgpImageGenerator, :call, 'dummy-png-bytes') { unit.ogp_image_relative_url }

    reloaded = Unit.with_attached_ogp_image.find(unit.id)

    assert_no_queries do
      assert reloaded.ogp_image.attached?
    end
  end

  test 'attach failure is rescued and does not retry within the cooldown (issue #1267)' do
    unit = Unit.create!(name: 'Attach Fail Unit', key: 'unit-ogp-attach-fail', status: :active)

    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    generator_call_count = 0
    generator = lambda { |_name|
      generator_call_count += 1
      'dummy-png-bytes'
    }

    result = nil
    stub_instance_method(ActiveStorage::Attached::One, :attach, ->(*) { raise 'boom' }) do
      stub_class_method(OgpImageGenerator, :call, generator) do
        result = unit.ogp_image_relative_url
        unit.ogp_image_relative_url
      end
    end

    assert_nil result
    assert_not unit.ogp_image.attached?
    assert_equal 1, generator_call_count, 'クールダウン中は再度generatorが呼ばれないはず'
  ensure
    Rails.cache = original_cache
  end

  test 'aliases_attributes= persists the hidden flag (issue #1311)' do
    unit = Unit.create!(name: 'Alias Hidden Unit', key: 'alias-hidden-unit-test', status: :active)

    unit.aliases_attributes = {
      '0' => { 'name' => '表示される別名', 'kana' => '', 'hidden' => '0' },
      '1' => { 'name' => '非表示の別名', 'kana' => '', 'hidden' => '1' }
    }
    unit.save!
    unit.reload

    visible_alias = unit.aliases.find { |a| a.name == '表示される別名' }
    hidden_alias = unit.aliases.find { |a| a.name == '非表示の別名' }

    assert_not visible_alias.hidden
    assert hidden_alias.hidden
  end
end
