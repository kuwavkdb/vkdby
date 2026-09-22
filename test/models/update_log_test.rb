# frozen_string_literal: true

require 'test_helper'

class UpdateLogTest < ActiveSupport::TestCase
  test 'for_sidebar includes only create/update actions on Unit/Person/CustomPage subjects' do
    unit = Unit.create!(name: 'For Sidebar Unit', key: 'for-sidebar-scope-unit', status: :active)
    item = Item.create!(title: 'For Sidebar Item', artists: [], release_date: Date.current,
                        link_url: 'http://example.com/for-sidebar-scope-item', asin: 'B000000002')

    create_log = UpdateLog.create!(user: users(:one), action: 'create', loggable: unit, subject: unit)
    update_log = UpdateLog.create!(user: users(:one), action: 'update', loggable: unit, subject: unit)
    UpdateLog.create!(user: users(:one), action: 'discard', loggable: unit, subject: unit)
    UpdateLog.create!(user: users(:one), action: 'change_key', loggable: unit, subject: unit)
    UpdateLog.create!(user: users(:one), action: 'create', loggable: item, subject: item)

    result = UpdateLog.for_sidebar.where(subject: unit)

    assert_includes result, create_log
    assert_includes result, update_log
    assert_equal 2, result.count
  end

  test 'subject defaults to nil and can be resolved to the referenced record' do
    unit = Unit.create!(name: 'Subject Resolution Unit', key: 'subject-resolution-unit', status: :active)
    section = unit.sections.create!(name: 'profile', markdown: 'body')

    log = UpdateLog.create!(user: users(:one), action: 'update', loggable: section, subject: unit)

    assert_equal unit, log.subject
    assert_equal section, log.loggable
  end
end
