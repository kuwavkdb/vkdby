# frozen_string_literal: true

require 'test_helper'

class BasicAttributeItemComponentTest < ViewComponent::TestCase
  # issue #2071: 項目ごとに薄い地の色で区切り（枠線は付けない）、見出しの横に値が収まらなければ値を下の段へ送る（flex-wrap）。
  # 奇数番目だけの区切り線は付けない
  test 'どの項目も同じ地の色で区切り、値は縮めずに右へ寄せる' do
    items = [{ label: 'パート', value: 'Vocal' }, { label: '血液型', value: 'A' }]

    render_inline(BasicAttributeItemComponent.with_collection(items))

    assert_selector 'div.flex-wrap.rounded-md.bg-zinc-50', count: 2
    assert_no_selector 'div.flex-wrap.border'
    assert_selector 'div.flex-wrap > dt + dd.ml-auto.shrink-0.text-right', count: 2
    assert_no_selector 'div[class*="border-l"]'
    assert_no_selector 'div[class*="col-span-2"]'
  end

  test '項目の数が奇数なら、最後の項目だけを2列分の幅にする' do
    items = [{ label: 'パート', value: 'Vocal' }, { label: '血液型', value: 'A' }, { label: '誕生日', value: '7 / 12' }]

    render_inline(BasicAttributeItemComponent.with_collection(items))

    assert_selector 'div[class*="col-span-2"]', count: 1
    assert_selector 'div[class*="col-span-2"] > dt', text: '誕生日'
  end
end
