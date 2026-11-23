# frozen_string_literal: true

require 'test_helper'

class ItemCardComponentTest < ViewComponent::TestCase
  # 長い商品名は末尾がフェードアウトで隠れるため、マウスを重ねて全文を確認できるようにする（issue #2102）
  test 'puts the full title in the title attribute of the item links' do
    title = '【限定】LIVE 2025 BIRTHDAY CELEBRATION (初回生産限定盤) (Blu-ray) (巾着付)'
    item = Item.create!(title:, release_date: '2027-01-29', link_url: 'https://example.com/item/2102')

    render_inline(ItemCardComponent.new(item_card: item))

    links = page.all("a[href='/items/#{item.id}']", visible: :all)

    assert_equal 2, links.size
    links.each { |link| assert_equal title, link[:title] }
  end
end
