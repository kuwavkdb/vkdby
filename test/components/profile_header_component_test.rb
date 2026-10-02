# frozen_string_literal: true

require 'test_helper'

class ProfileHeaderComponentTest < ActionView::TestCase
  include ViewComponent::TestHelpers

  test '名前とヨミガナが異なる場合はルビを表示する' do
    unit = Unit.create!(name: '黒夢', name_kana: 'クロユメ', key: 'header-kana-diff', status: :active)

    render_inline(ProfileHeaderComponent.new(resource: unit))

    assert_selector 'h1 rt', text: 'クロユメ'
  end

  test '名前とヨミガナが一致する場合はルビを表示しない（issue #1730）' do
    unit = Unit.create!(name: 'クロユメ', name_kana: 'クロユメ', key: 'header-kana-same', status: :active)

    render_inline(ProfileHeaderComponent.new(resource: unit))

    assert_selector 'h1', text: 'クロユメ'
    assert_no_selector 'h1 rt'
  end

  test '別名も名前とヨミガナが一致する場合はルビを表示しない（issue #1730）' do
    person = Person.create!(name: 'テスト', name_kana: 'テスト', key: 'header-kana-person',
                            aliases: [{ 'name' => 'アリアス', 'kana' => 'アリアス' }])

    render_inline(ProfileHeaderComponent.new(resource: person))

    assert_text 'アリアス'
    assert_no_selector 'rt'
  end
end
