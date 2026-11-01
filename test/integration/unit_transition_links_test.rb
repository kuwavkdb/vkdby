# frozen_string_literal: true

require 'test_helper'

# ステータス「移行」のユニットと後継ユニットの相互リンク（issue #1996）
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
end
