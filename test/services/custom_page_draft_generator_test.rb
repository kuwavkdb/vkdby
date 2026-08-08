# frozen_string_literal: true

require 'test_helper'

class CustomPageDraftGeneratorTest < ActiveSupport::TestCase
  def generate(name:, wiki:, title: nil)
    wikipage = Wikipage.new(id: 999, name: name, title: title, wiki: wiki)
    CustomPageDraftGenerator.generate(wikipage)
  end

  test '見出し !!!/!!/! はMarkdownの#に変換される' do
    draft = generate(name: 'test', wiki: "!!!大見出し\n!!中見出し\n!小見出し\n")
    assert_includes draft.body, '# 大見出し'
    assert_includes draft.body, '## 中見出し'
    assert_includes draft.body, '### 小見出し'
  end

  test '箇条書き */**/*** は入れ子のMarkdownリストに変換される' do
    draft = generate(name: 'test', wiki: "*一階層\n**二階層\n***三階層\n")
    assert_includes draft.body, '- 一階層'
    assert_includes draft.body, '  - 二階層'
    assert_includes draft.body, '    - 三階層'
  end

  test '[[label|url]] 形式のリンクはMarkdownリンクに変換される' do
    draft = generate(name: 'test', wiki: '[[オフィシャル|http://example.com/]]')
    assert_includes draft.body, '[オフィシャル](http://example.com/)'
  end

  test '[label|url] 形式のリンクもMarkdownリンクに変換される' do
    draft = generate(name: 'test', wiki: '[オフィシャル|http://example.com/]')
    assert_includes draft.body, '[オフィシャル](http://example.com/)'
  end

  test '[[PageName]] 形式の内部リンクは、対応するUnit/Personが見つからなければ平文化され警告が積まれる' do
    draft = generate(name: 'test', wiki: '[[存在しないバンド名]]')
    assert_includes draft.body, '存在しないバンド名'
    refute_includes draft.body, '[[存在しないバンド名]]'
    assert_equal(1, draft.warnings.count { |w| w.include?('内部リンク') })
  end

  test '[[PageName]] 形式の内部リンクは、同名のUnitが見つかればプロフィールへのMarkdownリンクになる' do
    Unit.create!(name: 'テストバンド', key: 'test-band-for-draft-generator')
    draft = generate(name: 'test', wiki: '[[テストバンド]]')
    assert_includes draft.body, '[テストバンド](/test-band-for-draft-generator)'
    assert_empty draft.warnings
  end

  test '[[PageName]] 形式の内部リンクは、同名のPersonが見つかればプロフィールへのMarkdownリンクになる' do
    Person.create!(name: 'テスト太郎', key: 'test-taro-for-draft-generator')
    draft = generate(name: 'test', wiki: '[[テスト太郎]]')
    assert_includes draft.body, '[テスト太郎](/test-taro-for-draft-generator)'
    assert_empty draft.warnings
  end

  test '[[label|target]] のtargetがURLでない場合は平文化され警告が積まれる（wikiページ名やサービス記法など）' do
    draft = generate(name: 'test', wiki: '[[2008/09/25|カレンダー/2008-9-25]] [[トーク|TBTV-Visual:452]]')
    assert_includes draft.body, '2008/09/25'
    assert_includes draft.body, 'トーク'
    refute_includes draft.body, '(カレンダー/2008-9-25)'
    refute_includes draft.body, '(TBTV-Visual:452)'
    assert_equal(2, draft.warnings.count { |w| w.include?('内部リンク') })
  end

  test '// で始まる行はコメントとして除去される' do
    draft = generate(name: 'test', wiki: "本文\n//これはコメント\n続き")
    refute_includes draft.body, 'これはコメント'
    assert_includes draft.body, '本文'
    assert_includes draft.body, '続き'
  end

  test '---- は Markdown の水平線に変換される' do
    draft = generate(name: 'test', wiki: "本文\n----\n続き")
    assert_includes draft.body, '---'
  end

  test '==打ち消し線== はMarkdownの~~打ち消し線~~に変換される' do
    draft = generate(name: 'test', wiki: '==受領証が届き次第画像を差し替えます==')
    assert_includes draft.body, '~~受領証が届き次第画像を差し替えます~~'
  end

  test 'include/snapshot/item プラグインはそのまま残る' do
    draft = generate(name: 'test', wiki: '{{include about,概要}} {{snapshot merry,1}} {{item B004X86P9U}}')
    assert_includes draft.body, '{{include about,概要}}'
    assert_includes draft.body, '{{snapshot merry,1}}'
    assert_includes draft.body, '{{item B004X86P9U}}'
  end

  test '未対応プラグインはTODOコメントに置き換えられ警告が積まれる' do
    draft = generate(name: 'test', wiki: '{{tweet v_ryugi}}')
    assert_includes draft.body, '<!-- TODO: 要手動対応 元記法: {{tweet v_ryugi}} -->'
    assert(draft.warnings.any? { |w| w.include?('tweet') })
  end

  test 'title が空の場合は name が使われる' do
    draft = generate(name: 'events', title: nil, wiki: '本文')
    assert_equal 'events', draft.title
  end

  test 'title がある場合はそちらが優先される' do
    draft = generate(name: 'events', title: 'vkdb主催イベント', wiki: '本文')
    assert_equal 'vkdb主催イベント', draft.title
  end

  test 'key は仮キー(page-<wikipage_id>)になる' do
    draft = generate(name: 'events', wiki: '本文')
    assert_equal 'page-999', draft.key
  end

  test 'old_key は旧サイトと同じ EUC-JP パーセントエンコードになる' do
    draft = generate(name: '義援活動', wiki: '本文')
    assert_equal '%B5%C1%B1%E7%B3%E8%C6%B0', draft.old_key
  end

  test 'ASCIIのnameはそのままエンコードされる' do
    draft = generate(name: 'events', wiki: '本文')
    assert_equal 'events', draft.old_key
  end
end
