# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test '{{include key,section}}で指定したCustomPageのセクション本文が展開される' do
    page = CustomPage.create!(key: 'target-page', title: 'Target', active: true)
    page.sections.create!(name: 'greeting', markdown: 'こんにちは')

    result = markdown('前 {{include target-page,greeting}} 後')

    assert_match(/こんにちは/, result)
  end

  test '{{include section}}（key省略）は自身のsectionableのセクションを参照する' do
    page = CustomPage.create!(key: 'self-page', title: 'Self', active: true)
    page.sections.create!(name: 'about', markdown: '自己紹介です')

    result = markdown('{{include about}}', sectionable: page)

    assert_match(/自己紹介です/, result)
  end

  test '対応するセクションが見つからない場合は空文字になる' do
    result = markdown('前{{include no-such-page,none}}後')

    assert_match(/前後/, result)
  end

  test '未登録のプラグイン名はそのまま文字列が残る' do
    result = markdown('{{unknown foo,bar}}')

    assert_match(/\{\{unknown foo,bar\}\}/, result)
  end
end
