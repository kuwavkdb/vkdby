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

  test '年指定なしの日付ページは「今日は何の日？」見出しとtitleを表示する（issue #1732）' do
    get birthday_date_path(month: 5, day: 30)

    assert_response :success
    assert_select 'title', text: /\A5月30日は何の日？/
    assert_select 'p', text: '今日は何の日？'
    assert_not_includes response.body, 'All Years Summary'
  end

  test '年指定なしの日付ページはadminにのみ「今日は何の日？」シェア用テキストを表示する（issue #1732）' do
    Trend.create!(title: 'シェア対象の動向', date: Date.new(1995, 5, 30), publish_start_at: Time.current,
                  unit_phenomenon: :other)

    get birthday_date_path(month: 5, day: 30)
    assert_select '#on-this-day-share-text', count: 0

    operator = User.create!(email: 'on-this-day-operator@example.com', name: 'Operator', password: 'password',
                            role: :super_operator)
    post login_path, params: { email: operator.email, password: 'password' }
    get birthday_date_path(month: 5, day: 30)
    assert_select '#on-this-day-share-text', count: 0

    delete logout_path
    admin = User.create!(email: 'on-this-day-admin@example.com', name: 'Admin', password: 'password', role: :admin)
    post login_path, params: { email: admin.email, password: 'password' }
    get birthday_date_path(month: 5, day: 30)

    assert_select '#on-this-day-share-text', text: /ヴィジュアル系今日は何の日？\n・1995年 シェア対象の動向\n/
  end

  test '年指定なしの日付ページは動向がなくても誕生日があればadminにシェア用テキストを表示する（issue #1732）' do
    Person.create!(name: 'シェア対象の誕生日', key: 'person-on-this-day-share', status: :active,
                   birthday: Date.new(1970, 6, 1))
    admin = User.create!(email: 'on-this-day-admin2@example.com', name: 'Admin', password: 'password', role: :admin)
    post login_path, params: { email: admin.email, password: 'password' }

    get birthday_date_path(month: 6, day: 1)

    assert_select '#on-this-day-share-text', text: /ヴィジュアル系今日は何の日？\n誕生日: シェア対象の誕生日\n/
  end

  test '年指定なしの日付ページは日付入りバナー画像をog:imageにする（issue #1746）' do
    get birthday_date_path(month: 5, day: 30)

    assert_select 'meta[property="og:image"][content=?]', 'http://www.example.com/date/-/5/30/ogp.png?v=2'
    assert_select 'meta[name="twitter:image"][content=?]', 'http://www.example.com/date/-/5/30/ogp.png?v=2'
  end

  test '年指定ありの日付ページのog:imageはデフォルト画像のまま' do
    get daily_path(year: 2020, month: 5, day: 30)

    assert_select 'meta[property="og:image"][content=?]',
                  "http://www.example.com#{Rails.application.config.site_ogp_image_path}"
  end
end
