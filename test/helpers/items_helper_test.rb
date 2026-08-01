# frozen_string_literal: true

require 'test_helper'

class ItemsHelperTest < ActionView::TestCase
  include ItemsHelper

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
