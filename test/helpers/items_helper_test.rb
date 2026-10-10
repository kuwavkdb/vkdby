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
