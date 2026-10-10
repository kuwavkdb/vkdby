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
