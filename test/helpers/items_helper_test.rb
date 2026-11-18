# frozen_string_literal: true

require 'test_helper'

class ItemsHelperTest < ActionView::TestCase
  include ItemsHelper

  test 'ASINがあるアイテムの購入リンクはAmazonのラベルになる' do
    item = Item.new(asin: 'B000000000')
    assert_equal 'Amazonで購入', item_purchase_label(item)
    assert_equal 'amazon.co.jp で購入', item_purchase_label(item, amazon_label: 'amazon.co.jp で購入')
  end

  test 'ASINが無いアイテムの購入リンクは販売サイトのラベルになる' do
    assert_equal '販売サイト で購入', item_purchase_label(Item.new(asin: nil))
    assert_equal '販売サイト で購入', item_purchase_label(Item.new(asin: ''), amazon_label: 'amazon.co.jp で購入')
  end

  test 'with_domain のときASINが無いアイテムは販売ページのドメインを示す' do
    item = Item.new(asin: nil, link_url: 'https://www.example-shop.jp/items/123')
    assert_equal '販売ページ（example-shop.jp）で購入', item_purchase_label(item, with_domain: true)
    assert_equal '販売サイト で購入', item_purchase_label(item)
  end

  test 'with_domain でもASINがあればAmazonのラベルのまま' do
    item = Item.new(asin: 'B000000000', link_url: 'https://www.amazon.co.jp/dp/B000000000')
    assert_equal 'amazon.co.jp で購入', item_purchase_label(item, amazon_label: 'amazon.co.jp で購入', with_domain: true)
  end

  test 'with_domain でもドメインを取り出せなければ販売サイトのラベルにする' do
    assert_equal '販売サイト で購入', item_purchase_label(Item.new(asin: nil, link_url: 'not a url'), with_domain: true)
  end

  test 'ASINがあり販売サイトがtower.jp以外ならTOWER RECORDSの検索導線は有効' do
    item = Item.new(asin: 'B000000000', link_url: 'https://www.amazon.co.jp/dp/B000000000')
    assert_not tower_records_search_disabled?(item)
  end

  test 'ASINが無ければTOWER RECORDSの検索導線は無効' do
    assert tower_records_search_disabled?(Item.new(asin: nil, link_url: 'https://www.example-shop.jp/items/123'))
  end

  test '販売サイトがtower.jpならTOWER RECORDSの検索導線は無効' do
    assert tower_records_search_disabled?(Item.new(asin: 'B000000000', link_url: 'https://tower.jp/item/123'))
    assert tower_records_search_disabled?(Item.new(asin: 'B000000000', link_url: 'https://www.tower.jp/item/123'))
    assert_not tower_records_search_disabled?(Item.new(asin: 'B000000000', link_url: 'https://notower.jp/item/123'))
  end

  test 'ASINがあるアイテムの購入リンクはAmazonへ直接遷移する' do
    item = Item.create!(title: 'Amazon Item', release_date: '2026-03-01', asin: 'B0CUSHION1',
                        link_url: 'https://www.amazon.co.jp/dp/B0CUSHION1')
    assert_match %r{\Ahttps://www\.amazon\.co\.jp/}, item_purchase_href(item)
  end

  test 'ASINが無いアイテムの購入リンクはクッションページを挟む' do
    item = Item.create!(title: 'Shop Item', release_date: '2026-03-01', link_url: 'https://www.example-shop.jp/items/1')
    assert_equal item_outbound_path(item), item_purchase_href(item)
  end

  test 'ASINが無くてもリンク先がtower.jpならクッションページを挟まず直接遷移する' do
    item = Item.create!(title: 'Tower Item', release_date: '2026-03-01', link_url: 'https://tower.jp/item/1234')
    assert_equal 'https://tower.jp/item/1234', item_purchase_href(item)
  end

  test '外部サイトへ遷移させられないURLの購入リンクは nil' do
    assert_nil item_purchase_href(Item.new(asin: nil, link_url: 'javascript:alert(1)'))
  end

  test 'ASINの有無で購入リンクの配色を切り替える' do
    assert_equal 'bg-amber-500 hover:bg-amber-600 text-black', item_purchase_color_class(Item.new(asin: 'B000000000'))
    assert_equal 'bg-teal-700 hover:bg-teal-800 text-white', item_purchase_color_class(Item.new(asin: nil))
  end

  test 'ASINが無くリンク先がtower.jpなら購入リンクはTOWER RECORDSの配色とラベルにする' do
    item = Item.new(asin: nil, link_url: 'https://tower.jp/item/123')
    assert_equal 'bg-yellow-400 hover:bg-yellow-500 text-red-700', item_purchase_color_class(item)
    assert_equal 'TOWER RECORDS で購入', item_purchase_label(item, with_domain: true)
    assert_equal 'タワレコで購入', item_purchase_label(item)
  end

  test '検索語はアーティスト名とタイトルをつなぎ、タイトル先頭のアーティスト名は外す' do
    item = Item.new(title: 'バンド 1st Album', artists: [{ 'name' => 'バンド' }])
    assert_equal 'バンド 1st Album', item_search_keyword(item)
  end

  test '検索語のアーティスト名は alias を優先する' do
    item = Item.new(title: 'Single', artists: [{ 'name' => '正式名', 'alias' => '表記名' }])
    assert_equal '表記名 Single', item_search_keyword(item)
  end

  test '検索語ではタイトル末尾の付記を外す' do
    artists = [{ 'name' => 'バンド' }]
    assert_equal 'バンド Live', item_search_keyword(Item.new(title: 'Live [DVD]', artists:))
    assert_equal 'バンド Single', item_search_keyword(Item.new(title: 'Single (初回限定盤)', artists:))
    assert_equal 'バンド Single', item_search_keyword(Item.new(title: 'Single (初回限定盤)(DVD付)', artists:))
    assert_equal 'バンド Single', item_search_keyword(Item.new(title: 'Single（通常盤）', artists:))
  end

  test '検索語ではタイトル末尾以外の括弧と、外すとタイトルが空になる括弧は外さない' do
    artists = [{ 'name' => 'バンド' }]
    assert_equal 'バンド (仮)タイトル', item_search_keyword(Item.new(title: '(仮)タイトル (通常盤)', artists:))
    assert_equal 'バンド (無題)', item_search_keyword(Item.new(title: '(無題)', artists:))
  end

  test 'key があればkeyベースのパスを返す' do
    assert_equal '/some-key', artist_profile_path({ 'key' => 'some-key', 'old_key' => 'legacy', 'name' => '名前' })
  end

  test 'key が無く old_key があれば old_key ベースのパスを返す' do
    assert_equal '/legacy.html', artist_profile_path({ 'old_key' => 'legacy', 'name' => '名前' })
  end

  test 'key も old_key も無い名前のみのアーティストはリンク先を持たない(nil)' do
    assert_nil artist_profile_path({ 'name' => '名前のみのアーティスト' })
  end

  test 'key があればkeyで絞り込んだitems_pathを返す' do
    assert_equal '/items?key=some-key', artist_items_path({ 'key' => 'some-key', 'old_key' => 'legacy', 'name' => '名前' })
  end

  test 'key が無く old_key があれば old_key で絞り込んだitems_pathを返す' do
    assert_equal '/items?old_key=legacy', artist_items_path({ 'old_key' => 'legacy', 'name' => '名前' })
  end

  test 'key も old_key も無い名前のみのアーティストは絞り込みリンク先を持たない(nil)' do
    assert_nil artist_items_path({ 'name' => '名前のみのアーティスト' })
  end
end
