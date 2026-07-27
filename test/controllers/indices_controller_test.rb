# frozen_string_literal: true

require 'test_helper'

class IndicesControllerTest < ActionDispatch::IntegrationTest
  test 'show excludes discarded units and people' do
    tag_index = TagIndex.create!(name: "Discard Test Index #{SecureRandom.hex(4)}")

    kept_unit = Unit.create!(name: 'Kept Unit', key: "kept-unit-#{SecureRandom.hex(4)}", status: :active)
    discarded_unit = Unit.create!(name: 'Discarded Unit', key: "discarded-unit-#{SecureRandom.hex(4)}",
                                  status: :active)
    discarded_unit.discard

    kept_person = Person.create!(name: 'Kept Person', key: "kept-person-#{SecureRandom.hex(4)}", status: :active)
    discarded_person = Person.create!(name: 'Discarded Person', key: "discarded-person-#{SecureRandom.hex(4)}",
                                      status: :active)
    discarded_person.discard

    TagIndexItem.create!(tag_index:, indexable: kept_unit)
    TagIndexItem.create!(tag_index:, indexable: discarded_unit)
    TagIndexItem.create!(tag_index:, indexable: kept_person)
    TagIndexItem.create!(tag_index:, indexable: discarded_person)

    get index_show_path(tag_index)

    assert_response :success
    assert_includes response.body, 'Kept Unit'
    assert_includes response.body, 'Kept Person'
    assert_not_includes response.body, 'Discarded Unit'
    assert_not_includes response.body, 'Discarded Person'
  end
end
