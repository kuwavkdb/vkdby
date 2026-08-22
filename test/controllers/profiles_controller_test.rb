# frozen_string_literal: true

require 'test_helper'

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test 'should show unit with dot in key' do
    unit = Unit.create!(name: 'Sick.', key: 'sick.', old_key: 'Sick.', status: :active)
    get profile_path(unit.key)
    assert_response :success
  end

  test 'should show person with dot in key' do
    person = Person.create!(name: 'Mr.Dot', key: 'mr.dot', old_key: 'Mr.Dot', status: :active)
    get profile_path(person.key)
    assert_response :success
  end

  test 'accessing a unit by its previous key redirects to the current key after change_key!' do
    unit = Unit.create!(name: 'Renamed Unit', key: 'unit-redirect-before', status: :active)
    unit.change_key!('unit-redirect-after')

    get profile_path('unit-redirect-before')

    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-redirect-after')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Renamed Unit'
  end

  test 'accessing a person by its previous key redirects to the current key after change_key!' do
    person = Person.create!(name: 'Renamed Person', key: 'person-redirect-before', status: :active)
    person.change_key!('person-redirect-after')

    get profile_path('person-redirect-before')

    assert_response :moved_permanently
    assert_redirected_to profile_path('person-redirect-after')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Renamed Person'
  end

  test 'accessing a key renamed twice requires two redirect hops to reach the final key' do
    unit = Unit.create!(name: 'Twice Renamed Unit', key: 'unit-chain-a', status: :active)
    unit.change_key!('unit-chain-b')
    unit.change_key!('unit-chain-c')

    get profile_path('unit-chain-a')
    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-chain-b')

    follow_redirect!
    assert_response :moved_permanently
    assert_redirected_to profile_path('unit-chain-c')

    follow_redirect!
    assert_response :success
    assert_includes response.body, 'Twice Renamed Unit'
  end

  test 'shows an unpublished message instead of content for a person tagged as unpublished' do
    person = Person.create!(name: 'Unpublished Person', key: 'person-unpublished-page', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get profile_path(person.key)

    assert_response :success
    assert_includes response.body, 'Unpublished Person'
    assert_includes response.body, '諸事情により掲載を停止しております。'
  end

  test 'shows an unpublished message instead of content for a unit tagged as unpublished' do
    unit = Unit.create!(name: 'Unpublished Unit', key: 'unit-unpublished-page', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unit)

    get profile_path(unit.key)

    assert_response :success
    assert_includes response.body, 'Unpublished Unit'
    assert_includes response.body, '諸事情により掲載を停止しております。'
  end

  test 'shows an active section but hides an inactive section' do
    unit = Unit.create!(name: 'Section Visibility Unit', key: 'unit-section-visibility', status: :active)
    unit.sections.create!(name: 'Visible Note', markdown: 'active section body')
    unit.sections.create!(name: 'Hidden Note', markdown: 'inactive section body', active: false)

    get profile_path(unit.key)

    assert_response :success
    assert_includes response.body, 'active section body'
    assert_not_includes response.body, 'inactive section body'
  end

  test 'unit trend list shows the recorded name when it differs from the current unit name' do
    unit = Unit.create!(name: 'Renamed Trend Unit', key: 'unit-trend-name-badge', status: :active)
    Trend.create!(title: 'Trend before rename', date: Date.current, publish_start_at: Time.current,
                  unit_phenomenon: :other, units: [{ 'unit_id' => unit.id, 'name' => 'Old Trend Unit Name' }])

    get profile_path(unit.key)

    assert_response :success
    assert_includes response.body, 'Old Trend Unit Name'
  end
end
