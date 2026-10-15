# frozen_string_literal: true

require 'test_helper'

# 構造化データ（JSON-LD）の出力（issue #1254）
class JsonLdTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
  def json_ld_data
    scripts = css_select('script[type="application/ld+json"]')
    assert_equal 1, scripts.size
    JSON.parse(scripts.first.text)
  end

  test '作品詳細はMusicAlbumを出力する' do
    unit = Unit.create!(name: 'JsonLd Unit', key: 'json-ld-unit', status: :active)
    person = Person.create!(name: 'JsonLd Person', key: 'json-ld-person', status: :active)
    item = Item.create!(title: 'JsonLd Album', release_date: '2026-03-01', link_url: 'http://example.com/json-ld-item',
                        image_url: 'https://example.com/jacket.jpg',
                        artists: [{ 'name' => unit.name, 'key' => unit.key },
                                  { 'name' => person.name, 'key' => person.key },
                                  { 'name' => 'ページのないアーティスト' }])

    get item_path(item)

    data = json_ld_data
    assert_equal 'MusicAlbum', data['@type']
    assert_equal 'JsonLd Album', data['name']
    assert_equal '2026-03-01', data['datePublished']
    assert_equal 'https://example.com/jacket.jpg', data['image']
    assert_equal "http://www.example.com#{item_path(item)}", data['url']
    assert_equal [
      { '@type' => 'MusicGroup', 'name' => 'JsonLd Unit', 'url' => 'http://www.example.com/json-ld-unit' },
      { '@type' => 'Person', 'name' => 'JsonLd Person', 'url' => 'http://www.example.com/json-ld-person' },
      { '@type' => 'MusicGroup', 'name' => 'ページのないアーティスト' }
    ], data['byArtist']
  end

  test '会場詳細はMusicVenueを出力し、空の項目は出さない' do
    venue = Venue.create!(key: 'json-ld-venue', name: '新宿LOFT', prefecture: '東京都', capacity: 550,
                          address: 'MAP:東京都新宿区歌舞伎町1-12-9', latitude: 35.6948, longitude: 139.7012,
                          name_log: [{ 'name' => '旧LOFT' }, { 'name' => '新宿LOFT' }],
                          aliases: [{ 'name' => 'LOFT' }, { 'name' => '非表示の別名', 'hidden' => true }])
    bare = Venue.create!(key: 'json-ld-bare-venue', name: '情報の少ない会場')

    get venue_path(venue.key)

    data = json_ld_data
    assert_equal 'MusicVenue', data['@type']
    assert_equal '新宿LOFT', data['name']
    assert_equal %w[LOFT 旧LOFT], data['alternateName']
    assert_equal({ '@type' => 'PostalAddress', 'streetAddress' => '東京都新宿区歌舞伎町1-12-9',
                   'addressRegion' => '東京都', 'addressCountry' => 'JP' }, data['address'])
    assert_equal({ '@type' => 'GeoCoordinates', 'latitude' => 35.6948, 'longitude' => 139.7012 }, data['geo'])
    assert_equal 550, data['maximumAttendeeCapacity']

    get venue_path(bare.key)

    data = json_ld_data
    assert_equal %w[@context @type name url], data.keys
  end

  test 'トップページはWebSiteを出力する' do
    CustomPage.create!(key: 'index', title: 'トップページ', active: true, body: 'body')

    get root_path

    data = json_ld_data
    assert_equal 'WebSite', data['@type']
    assert_equal Rails.application.config.site_name, data['name']
    assert_equal 'http://www.example.com/', data['url']
  end

  test '値に</script>が含まれていてもタグを閉じない' do
    item = Item.create!(title: '</script><script>alert(1)</script>', release_date: '2026-03-01',
                        link_url: 'http://example.com/json-ld-escape-item')

    get item_path(item)

    assert_not_includes response.body, '</script><script>alert(1)'
    assert_equal '</script><script>alert(1)</script>', json_ld_data['name']
  end

  test 'ユニットのページはMusicGroupを出力し、メンバーは現在のスナップショットの在籍メンバーだけにする' do
    unit = Unit.create!(name: 'JsonLd Band', key: 'json-ld-band', status: :disbanded,
                        name_log: [{ 'name' => '旧JsonLd Band' }],
                        aliases: [{ 'name' => 'JLB' }, { 'name' => '非表示の別名', 'hidden' => true }],
                        activity_period: [{ 'from' => '2010/01/**', 'to' => '2012/**/**' },
                                          { 'from' => '2015/03/05', 'to' => '2020/12/31' }])
    unit.links.create!(url: 'https://x.com/json_ld_band', sort_order: 1)
    vocal = Person.create!(name: 'JsonLd Vocal', key: 'json-ld-vocal', status: :active)
    old_snapshot = unit.unit_snapshots.create!(snapshot_date: Date.new(2011, 1, 1))
    old_snapshot.snapshot_people.create!(person_name: '旧スナップショットのメンバー', part: :bass, sort_order: 1)
    snapshot = unit.unit_snapshots.create!(snapshot_date: Date.new(2020, 1, 1), current: true)
    snapshot.snapshot_people.create!(person: vocal, part: :vocal, sort_order: 1)
    snapshot.snapshot_people.create!(person_name: 'ページのないメンバー', part: :guitar, sort_order: 2)
    snapshot.snapshot_people.create!(person_name: '脱退したメンバー', part: :bass, status: :left, sort_order: 3)
    snapshot.snapshot_people.create!(person_name: 'サポートメンバー', part: :drums, support: true, sort_order: 4)

    get profile_path(unit.key)

    data = json_ld_data
    assert_equal 'MusicGroup', data['@type']
    assert_equal 'JsonLd Band', data['name']
    assert_equal 'http://www.example.com/json-ld-band', data['url']
    assert_equal ['JLB', '旧JsonLd Band'], data['alternateName']
    assert_equal 'ヴィジュアル系', data['genre']
    assert_equal '2010-01', data['foundingDate']
    assert_equal '2020-12-31', data['dissolutionDate']
    assert_equal ['https://x.com/json_ld_band'], data['sameAs']
    assert_equal [{ '@type' => 'Person', 'name' => 'JsonLd Vocal', 'url' => 'http://www.example.com/json-ld-vocal' },
                  { '@type' => 'Person', 'name' => 'ページのないメンバー' }], data['member']
  end

  test '活動中のユニットには解散日を出さない' do
    unit = Unit.create!(name: 'JsonLd Active Band', key: 'json-ld-active-band', status: :active,
                        activity_period: [{ 'from' => '2010/**/**', 'to' => '2012/05/**' }])

    get profile_path(unit.key)

    data = json_ld_data
    assert_equal '2010', data['foundingDate']
    assert_nil data['dissolutionDate']
  end

  test '個人のページはPersonを出力し、所属は今在籍しているユニットだけにする' do
    person = Person.create!(name: 'JsonLd Person Page', key: 'json-ld-person-page', status: :active,
                            birthday: Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), birth_year: 1985, hometown: '東京都',
                            blood: 'A', name_log: [{ 'name' => '旧名義' }])
    current_unit = Unit.create!(name: 'JsonLd Current Unit', key: 'json-ld-current-unit', status: :active)
    current_unit.unit_snapshots.create!(snapshot_date: Date.current, current: true)
                .snapshot_people.create!(person: person, part: :vocal, sort_order: 1)
    left_unit = Unit.create!(name: 'JsonLd Left Unit', key: 'json-ld-left-unit', status: :active)
    left_unit.unit_snapshots.create!(snapshot_date: Date.current, current: true)
             .snapshot_people.create!(person: person, part: :vocal, status: :left, sort_order: 1)

    get profile_path(person.key)

    data = json_ld_data
    assert_equal 'Person', data['@type']
    assert_equal 'JsonLd Person Page', data['name']
    assert_equal ['旧名義'], data['alternateName']
    assert_equal '1985-07-12', data['birthDate']
    assert_equal({ '@type' => 'Place', 'name' => '東京都' }, data['homeLocation'])
    assert_equal [{ '@type' => 'MusicGroup', 'name' => 'JsonLd Current Unit',
                    'url' => 'http://www.example.com/json-ld-current-unit' }], data['memberOf']
    assert_not data.key?('bloodType')
  end

  test '生年が分からない個人の誕生日は月日だけを出す' do
    person = Person.create!(name: 'JsonLd No Year', key: 'json-ld-no-year', status: :active,
                            birthday: Date.new(Person::DUMMY_BIRTH_YEAR, 2, 29))

    get profile_path(person.key)

    assert_equal '--02-29', json_ld_data['birthDate']
  end

  test '非公開の個人には構造化データを出さない' do
    person = Person.create!(name: 'JsonLd Unpublished', key: 'json-ld-unpublished', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get profile_path(person.key)

    assert_response :success
    assert_select 'script[type="application/ld+json"]', count: 0
  end

  test '結成日・解散日は活動期間の並び順によらず最も古い・新しい日付にし、文章が続く値は読まない' do
    unit = Unit.create!(name: 'JsonLd Unordered', key: 'json-ld-unordered', status: :disbanded,
                        activity_period: [{ 'from' => '2015/03/05', 'to' => '2018/06/**' },
                                          { 'from' => '2010/01/**', 'to' => '2012/**/**' },
                                          { 'from' => '2019頃', 'to' => '2013以降状況不明' },
                                          { 'from' => '2020/01/01', 'to' => '****/**/**' }])

    get profile_path(unit.key)

    data = json_ld_data
    assert_equal '2010-01', data['foundingDate']
    assert_equal '2018-06', data['dissolutionDate']
  end

  test 'sameAsにはYouTubeの動画やXの個別投稿へのリンクを入れない' do
    unit = Unit.create!(name: 'JsonLd SameAs', key: 'json-ld-same-as', status: :active)
    unit.links.create!(url: 'https://x.com/json_ld_same_as', sort_order: 1)
    unit.links.create!(url: 'https://www.youtube.com/watch?v=abcdefghijk', sort_order: 2)
    unit.links.create!(url: 'https://x.com/json_ld_same_as/status/1234567890', sort_order: 3)
    unit.links.create!(url: 'https://www.youtube.com/@json_ld_same_as', sort_order: 4)

    get profile_path(unit.key)

    assert_equal ['https://x.com/json_ld_same_as', 'https://www.youtube.com/@json_ld_same_as'], json_ld_data['sameAs']
  end

  test 'メンバーには非公開の個人を出さず、転送している個人は転送先のURLにする' do
    unit = Unit.create!(name: 'JsonLd Hidden Members', key: 'json-ld-hidden-members', status: :active)
    hidden = Person.create!(name: 'JsonLd Hidden Member', key: 'json-ld-hidden-member', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: hidden)
    moved = Person.create!(name: 'JsonLd Moved Member', key: 'json-ld-moved-member', status: :active,
                           destination_key: 'json-ld-moved-destination')
    snapshot = unit.unit_snapshots.create!(snapshot_date: Date.current, current: true)
    snapshot.snapshot_people.create!(person: hidden, part: :vocal, sort_order: 1)
    snapshot.snapshot_people.create!(person: moved, part: :guitar, sort_order: 2)

    get profile_path(unit.key)

    assert_equal [{ '@type' => 'Person', 'name' => 'JsonLd Moved Member',
                    'url' => 'http://www.example.com/json-ld-moved-destination' }], json_ld_data['member']
  end

  test '個人の所属には解散したユニットと非公開のユニットを含めず、別名も出す' do
    person = Person.create!(name: 'JsonLd Member Of', key: 'json-ld-member-of', status: :active,
                            aliases: [{ 'name' => '別名義' }, { 'name' => '非表示の別名', 'hidden' => true }])
    disbanded = Unit.create!(name: 'JsonLd Disbanded', key: 'json-ld-disbanded', status: :disbanded)
    hidden = Unit.create!(name: 'JsonLd Hidden Unit', key: 'json-ld-hidden-unit', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: hidden)
    [disbanded, hidden].each do |unit|
      unit.unit_snapshots.create!(snapshot_date: Date.current, current: true)
          .snapshot_people.create!(person: person, part: :vocal, sort_order: 1)
    end

    get profile_path(person.key)

    data = json_ld_data
    assert_nil data['memberOf']
    assert_equal ['別名義'], data['alternateName']
  end
end
