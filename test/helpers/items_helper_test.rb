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
end
