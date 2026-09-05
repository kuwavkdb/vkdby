# frozen_string_literal: true

require 'test_helper'

class ItemsControllerTest < ActionDispatch::IntegrationTest # rubocop:disable Metrics/ClassLength
  test 'index does not resolve artist info for a discarded unit key' do
    unit = Unit.create!(name: 'Discarded Unit', key: 'discarded-unit-items-test', status: :active)
    unit.discard

    get items_path(key: unit.key)

    assert_response :success
    assert_not_includes response.body, 'Discarded Unit'
  end

  test 'index does not resolve artist info for a discarded person key' do
    person = Person.create!(name: 'Discarded Person', key: 'discarded-person-items-test', status: :active)
    person.discard

    get items_path(key: person.key)

    assert_response :success
    assert_not_includes response.body, 'Discarded Person'
  end

  test 'index resolves artist info for a kept unit key' do
    unit = Unit.create!(name: 'Kept Unit', key: 'kept-unit-items-test', status: :active)

    get items_path(key: unit.key)

    assert_response :success
    assert_includes response.body, 'Kept Unit'
  end

  test 'index filters by title with q param' do
    get items_path(q: 'Item One')

    assert_response :success
    assert_includes response.body, 'Item One'
    assert_not_includes response.body, 'Item Two'
  end

  test 'index filters by title with full-width alphanumeric q param' do
    item = Item.create!(
      title: 'ABC123',
      release_date: '2026-03-01',
      link_url: "http://example.com/zenkaku-search-item-#{SecureRandom.hex(4)}"
    )

    get items_path(q: 'ＡＢＣ１２３')

    assert_response :success
    assert_includes response.body, item.title
  end

  test 'show hides non-omnibus artists from the header when various_artists is true' do
    item = Item.create!(
      title: 'VA Compilation',
      artists: [{ 'name' => 'オムニバス' }, { 'name' => 'Artist A' }, { 'name' => 'Artist B' }],
      various_artists: true,
      release_date: '2026-03-01',
      link_url: "http://example.com/va-item-#{SecureRandom.hex(4)}"
    )

    get item_path(item)

    assert_response :success
    header_text = Nokogiri::HTML(response.body).at_css('h1').text
    assert_includes header_text, 'オムニバス'
    assert_not_includes header_text, 'Artist A'
    assert_not_includes header_text, 'Artist B'
    assert_includes response.body, 'Artist A'
    assert_includes response.body, 'Artist B'
  end

  test 'show lists all artists in the header when various_artists is false' do
    item = Item.create!(
      title: 'Regular Item',
      artists: [{ 'name' => 'オムニバス' }, { 'name' => 'Artist A' }],
      various_artists: false,
      release_date: '2026-03-01',
      link_url: "http://example.com/non-va-item-#{SecureRandom.hex(4)}"
    )

    get item_path(item)

    assert_response :success
    header_text = Nokogiri::HTML(response.body).at_css('h1').text
    assert_includes header_text, 'オムニバス'
    assert_includes header_text, 'Artist A'
  end

  test 'show renders a publicly visible section' do
    item = Item.create!(
      title: 'Item With Section',
      release_date: '2026-03-01',
      link_url: "http://example.com/item-with-section-#{SecureRandom.hex(4)}"
    )
    item.sections.create!(name: 'メモ', wiki_text: '本文です')

    get item_path(item)

    assert_response :success
    assert_includes response.body, 'メモ'
    assert_includes response.body, '本文です'
  end

  test 'show does not render an inactive (non-public) section' do
    item = Item.create!(
      title: 'Item With Inactive Section',
      release_date: '2026-03-01',
      link_url: "http://example.com/item-with-inactive-section-#{SecureRandom.hex(4)}"
    )
    item.sections.create!(name: '非公開メモ', wiki_text: '非公開の本文', active: false)

    get item_path(item)

    assert_response :success
    assert_not_includes response.body, '非公開メモ'
  end

  test 'show does not render a link for a name-only artist' do
    item = Item.create!(
      title: 'Name Only Artist Item',
      artists: [{ 'name' => '名前のみのアーティスト' }],
      release_date: '2026-03-01',
      link_url: "http://example.com/name-only-artist-item-#{SecureRandom.hex(4)}"
    )

    get item_path(item)

    assert_response :success
    assert_includes response.body, '名前のみのアーティスト'
    assert_not_includes response.body, %(href="/#{ERB::Util.url_encode('名前のみのアーティスト'.encode('EUC-JP'))}.html")
  end

  test 'show renders a see-all button per artist whose own related item count exceeds 10, linking only to that artist' do
    unit_a = Unit.create!(name: 'Artist A', key: "artist-a-#{SecureRandom.hex(4)}", status: :active)
    unit_b = Unit.create!(name: 'Artist B', key: "artist-b-#{SecureRandom.hex(4)}", status: :active)

    item = Item.create!(
      title: 'Multi Artist Item',
      artists: [
        { 'name' => unit_a.name, 'key' => unit_a.key },
        { 'name' => unit_b.name, 'key' => unit_b.key }
      ],
      release_date: '2026-03-01',
      link_url: "http://example.com/multi-artist-item-#{SecureRandom.hex(4)}"
    )
    11.times do |i|
      Item.create!(
        title: "Artist A Related Item #{i}",
        artists: [{ 'name' => unit_a.name, 'key' => unit_a.key }],
        release_date: '2026-03-01',
        link_url: "http://example.com/related-item-a-#{i}-#{SecureRandom.hex(4)}"
      )
    end
    2.times do |i|
      Item.create!(
        title: "Artist B Related Item #{i}",
        artists: [{ 'name' => unit_b.name, 'key' => unit_b.key }],
        release_date: '2026-03-01',
        link_url: "http://example.com/related-item-b-#{i}-#{SecureRandom.hex(4)}"
      )
    end

    get item_path(item)

    assert_response :success
    assert_includes response.body, "#{unit_a.name} の全作品を見る"
    assert_includes response.body, items_path(key: unit_a.key)
    assert_not_includes response.body, "#{unit_b.name} の全作品を見る"
  end

  test 'show excludes items that only share an artist name when that artist has a key or old_key' do
    item = Item.create!(
      title: 'VA Compilation With Generic Name',
      artists: [{ 'name' => 'オムニバス', 'old_key' => 'omnibus-generic-name-unique-old-key' }],
      release_date: '2026-03-01',
      link_url: "http://example.com/va-generic-name-item-#{SecureRandom.hex(4)}"
    )
    # 同じ「オムニバス」という名前だが、別のold_keyを持つ無関係な作品
    15.times do |i|
      Item.create!(
        title: "Unrelated VA Album #{i}",
        artists: [{ 'name' => 'オムニバス', 'old_key' => "unrelated-omnibus-old-key-#{i}" }],
        release_date: '2026-03-01',
        link_url: "http://example.com/unrelated-va-#{i}-#{SecureRandom.hex(4)}"
      )
    end

    get item_path(item)

    assert_response :success
    assert_not_includes response.body, 'Unrelated VA Album'
    assert_not_includes response.body, 'オムニバス の全作品を見る'
  end

  test 'index does not list a discarded item' do
    item = Item.create!(
      title: "Discarded Item #{SecureRandom.hex(4)}",
      release_date: '2026-03-01',
      link_url: "http://example.com/discarded-index-item-#{SecureRandom.hex(4)}"
    )
    item.discard

    get items_path(q: item.title)

    assert_response :success
    assert_not_includes response.body, item_path(item)
  end

  test 'show returns 404 for a discarded item' do
    item = Item.create!(
      title: 'Discarded Show Item',
      release_date: '2026-03-01',
      link_url: "http://example.com/discarded-show-item-#{SecureRandom.hex(4)}"
    )
    item.discard

    get item_path(item)

    assert_response :not_found
  end

  test 'index filters by artist name with q param' do
    item = Item.create!(
      title: 'Searchable Artist Item',
      artists: [{ 'name' => 'Unique Artist Name' }],
      release_date: '2026-03-01',
      link_url: 'http://example.com/searchable-artist-item'
    )

    get items_path(q: 'Unique Artist Name')

    assert_response :success
    assert_includes response.body, item.title
    assert_not_includes response.body, 'Item One'
  end
end
