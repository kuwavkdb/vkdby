# frozen_string_literal: true

require 'test_helper'

class RandomUnitsControllerTest < ActionDispatch::IntegrationTest
  # issue #2124: 公開中のバンドからランダムに1件を選んでリダイレクトする
  test 'random redirects to a published band page regardless of status' do
    Unit.where(unit_type: :band).find_each(&:discard)
    band = Unit.create!(name: 'Random Disbanded Band', key: 'random-disbanded-band', unit_type: :band,
                        status: :disbanded)

    get random_units_path

    assert_redirected_to profile_path(band.key)
    assert_equal 'no-store', response.headers['Cache-Control']
  end

  test 'random skips units that are not published bands' do
    Unit.where(unit_type: :band).find_each(&:discard)
    Unit.create!(name: 'Random Not Band', key: 'random-not-band', unit_type: :unit)
    Unit.create!(name: 'Random Provisional Band', key: 'random-provisional-band', unit_type: :band,
                 provisional: true)
    Unit.create!(name: 'Random Discarded Band', key: 'random-discarded-band', unit_type: :band).discard
    unpublished = Unit.create!(name: 'Random Unpublished Band', key: 'random-unpublished-band', unit_type: :band)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unpublished)

    get random_units_path

    assert_redirected_to units_path
  end
end
