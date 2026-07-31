# frozen_string_literal: true

require 'test_helper'

class DailyControllerTest < ActionDispatch::IntegrationTest
  test 'birthday date page excludes a person tagged as unpublished' do
    person = Person.create!(name: 'Unpublished Birthday Person', key: 'person-unpublished-birthday',
                            status: :active, birthday: Date.new(1904, 5, 1))
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get birthday_date_path(month: 5, day: 1)

    assert_response :success
    assert_not_includes response.body, 'Unpublished Birthday Person'
  end

  test 'daily page excludes a person tagged as unpublished' do
    date = Date.new(2020, 5, 1)
    person = Person.create!(name: 'Unpublished Daily Person', key: 'person-unpublished-daily',
                            status: :active, birthday: date)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get daily_path(year: date.year, month: date.month, day: date.day)

    assert_response :success
    assert_not_includes response.body, 'Unpublished Daily Person'
  end
end
