# frozen_string_literal: true

require 'test_helper'

class YearlyControllerTest < ActionDispatch::IntegrationTest
  test 'yearly page excludes a person tagged as unpublished from the born persons list' do
    person = Person.create!(name: 'Unpublished Yearly Person', key: 'person-unpublished-yearly',
                            status: :active, birth_year: 1999, birthday: Date.new(1904, 5, 1))
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get yearly_path(year: 1999)

    assert_response :success
    assert_not_includes response.body, 'Unpublished Yearly Person'
  end
end
