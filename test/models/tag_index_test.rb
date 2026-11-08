# frozen_string_literal: true

require 'test_helper'

# issue #2027
class TagIndexTest < ActiveSupport::TestCase
  test 'redirect flag defaults to off' do
    assert_not TagIndex.new(name: 'タグ').redirect_to_related_url
  end

  test 'related url accepts internal paths' do
    assert TagIndex.new(name: 'タグ', related_url: '/units/example?tab=1').valid?
  end

  test 'related url rejects external urls' do
    ['https://example.com/', '//example.com/', '/\\example.com', 'units/example'].each do |url|
      tag_index = TagIndex.new(name: 'タグ', related_url: url)
      assert_not tag_index.valid?, url
      assert tag_index.errors.of_kind?(:related_url, :invalid), url
    end
  end

  test 'redirect requires related url' do
    tag_index = TagIndex.new(name: 'タグ', redirect_to_related_url: true)
    assert_not tag_index.valid?
    assert tag_index.errors.of_kind?(:related_url, :blank)
  end

  test 'redirect_target returns related url only when redirect is enabled' do
    assert_nil TagIndex.new(related_url: '/units/example').redirect_target
    assert_equal '/units/example', TagIndex.new(related_url: '/units/example', redirect_to_related_url: true).redirect_target
  end

  test 'blank related url is normalized to nil' do
    assert_nil TagIndex.new(related_url: '  ').related_url
  end

  test 'related url rejects the tag own page' do
    tag_index = TagIndex.create!(name: "自己転送タグ #{SecureRandom.hex(4)}")
    ["/index/show/#{tag_index.id}", "/index/show/#{tag_index.id}/", "/index/show/#{tag_index.id}?a=1"].each do |url|
      tag_index.related_url = url
      assert_not tag_index.valid?, url
      assert tag_index.errors.added?(:related_url, 'にこのタグ自身のページは指定できません'), url
    end
  end

  test 'related url accepts another tag page' do
    tag_index = TagIndex.create!(name: "別タグ転送 #{SecureRandom.hex(4)}")
    tag_index.related_url = "/index/show/#{tag_index.id + 1}"
    assert tag_index.valid?
  end
end
