# frozen_string_literal: true

require 'test_helper'

class MemberRowComponentTest < ActionView::TestCase
  include ViewComponent::TestHelpers

  test 'sns_icon_for returns :x for an "@handle" account' do
    member = UnitPerson.new(part: 'vocal', sns: ['@vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal :x, component.sns_icon_for('@vocalist')
  end

  test 'sns_icon_for returns :instagram for an Instagram URL' do
    member = UnitPerson.new(part: 'vocal', sns: ['https://instagram.com/vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal :instagram, component.sns_icon_for('https://instagram.com/vocalist')
  end

  test 'sns_icon_for returns nil for a non-SNS URL' do
    member = UnitPerson.new(part: 'vocal', sns: ['https://example.com/official'])

    component = MemberRowComponent.new(member: member)

    assert_nil component.sns_icon_for('https://example.com/official')
  end

  test 'sns_url_for converts an "@handle" account to an x.com URL' do
    member = UnitPerson.new(part: 'vocal', sns: ['@vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal 'https://x.com/vocalist', component.sns_url_for('@vocalist')
  end

  test 'sns_url_for keeps a URL as-is' do
    member = UnitPerson.new(part: 'vocal', sns: ['https://instagram.com/vocalist'])

    component = MemberRowComponent.new(member: member)

    assert_equal 'https://instagram.com/vocalist', component.sns_url_for('https://instagram.com/vocalist')
  end

  test 'renders distinct SNS icons for X, Instagram, YouTube and a non-SNS link' do
    member = UnitPerson.new(
      part: 'vocal',
      sns: ['@vocalist', 'https://instagram.com/vocalist', 'https://youtube.com/@vocalist', 'https://example.com/official']
    )

    render_inline(MemberRowComponent.new(member: member))

    assert_text '(Twitter)'
    assert_text '(Instagram)'
    assert_text '(YouTube)'
    assert_text '(外部サイト)'
  end

  test '行頭が // または # のSNSアカウントは表示しない（issue #1854）' do
    member = UnitPerson.new(
      part: 'vocal',
      sns: ['@vocalist', '// https://instagram.com/old_account', '#@old_handle', ' # https://example.com/old']
    )

    render_inline(MemberRowComponent.new(member: member))

    assert_selector 'a', count: 1
    assert_selector "a[href='https://x.com/vocalist']"
    assert_no_text '(Instagram)'
  end

  test '経歴が「→」で終わるメンバーは最後に活動状況不明のバッジを出す（issue #1992）' do
    member = UnitPerson.new(part: 'vocal', inline_history: '[[BandA]] →')

    render_inline(MemberRowComponent.new(member: member))

    assert_selector '.history-row span.ring-1', text: '活動状況不明'
    assert_no_text '現在不明'
  end

  test '経歴の {{category 個人/状況不明}} は活動状況不明のバッジで出す（issue #1992）' do
    member = UnitPerson.new(part: 'vocal', inline_history: '[[BandA]] → {{category 個人/状況不明}}')

    render_inline(MemberRowComponent.new(member: member))

    assert_selector '.history-row span.ring-1', text: '活動状況不明'
    assert_no_text '個人/状況不明'
  end
end
