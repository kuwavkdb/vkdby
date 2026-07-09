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

  test 'other attributes can still be updated when key is unchanged' do
    unit = Unit.create!(name: 'Existing Unit', key: 'unchanged-unit-key-test', status: :active)

    assert unit.update(name: 'Renamed Unit')
    assert_equal 'Renamed Unit', unit.reload.name
  end
end
