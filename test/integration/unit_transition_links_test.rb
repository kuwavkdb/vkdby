# frozen_string_literal: true

require 'test_helper'

# ステータス「移行」のユニットと後継ユニットの相互リンク・説明文（issue #1996）
class UnitTransitionLinksTest < ActionDispatch::IntegrationTest
  setup do
    @successor = Unit.create!(name: 'Link Successor', key: 'link-successor', status: :active)
    @unit = Unit.create!(name: 'Link Transitioned', key: 'link-transitioned', status: :transitioned,
                         transitioned_unit: @successor)
  end

  test '移行したユニットの基本情報に移行先のユニットへのリンクを出す' do
    get profile_path(@unit.key)

    assert_select 'dt', text: '移行先'
    assert_select "dd a[href='#{profile_path(@successor.key)}']", text: 'Link Successor'
  end

  test '後継ユニットの基本情報に前身のユニットへのリンクを出す' do
    get profile_path(@successor.key)

    assert_select 'dt', text: '前身'
    assert_select "dd a[href='#{profile_path(@unit.key)}']", text: 'Link Transitioned'
  end

  test '後継ユニットが仮登録なら、移行先のリンクを出さない' do
    @successor.update!(provisional: true)

    get profile_path(@unit.key)

    assert_select "a[href='#{profile_path(@successor.key)}']", count: 0
  end

  test '移行したユニットの説明文は解散と書かず、後継ユニットとして活動を継続したことを書く' do
    @unit.update!(activity_period: [{ 'from' => '2012/04/**', 'to' => '2018/12/24' }])

    get profile_path(@unit.key)

    assert_equal 'Link Transitionedは2012年結成のバンド。2018年にLink Successorとして活動を継続。' \
                 'バンドの歴史やメンバーの経歴、音源等を掲載。',
                 css_select('meta[name="description"]').first['content']
  end
end
