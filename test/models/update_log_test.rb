# frozen_string_literal: true

require 'test_helper'

class UpdateLogTest < ActiveSupport::TestCase
  test 'subject defaults to nil and can be resolved to the referenced record' do
    unit = Unit.create!(name: 'Subject Resolution Unit', key: 'subject-resolution-unit', status: :active)
    section = unit.sections.create!(name: 'profile', markdown: 'body')

    log = UpdateLog.create!(user: users(:one), action: 'update', loggable: section, subject: unit)

    assert_equal unit, log.subject
    assert_equal section, log.loggable
  end
end
