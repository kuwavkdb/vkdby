# frozen_string_literal: true

require 'test_helper'

class TrendsHelperTest < ActionView::TestCase
  include TrendsHelper

  test 'unit_name_badgeはユニット名をzincのバッジ<span>で返す' do
    html = unit_name_badge('名前だけのユニット')

    assert_dom_equal %(<span class="#{TrendsHelper::UNIT_NAME_BADGE_CLASS}">名前だけのユニット</span>), html
    assert_includes TrendsHelper::UNIT_NAME_BADGE_CLASS, 'bg-zinc-50'
    assert_not_includes TrendsHelper::UNIT_NAME_BADGE_CLASS, 'gray'
  end

  test 'unit_name_badgeはユニット名をエスケープする' do
    html = unit_name_badge('<script>alert(1)</script>')

    assert_includes html, '&lt;script&gt;alert(1)&lt;/script&gt;'
    assert_not_includes html, '<script>'
  end
end
