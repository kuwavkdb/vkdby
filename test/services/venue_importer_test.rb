# frozen_string_literal: true

require 'test_helper'

class VenueImporterTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
  WikipageStub = Struct.new(:id, :wiki, :name, :title) do
    def attributes
      {}
    end
  end

  def import(id:, name:, wiki:, title: nil)
    stub = WikipageStub.new(id, wiki, name, title)
    VenueImporter.import(stub)
  end

  test '基本的な名称・かな・住所・都道府県・リンクを取り込む' do
    wiki = <<~WIKI
      !!!新宿ロフト（シンジュクロフト）
      *{{category ライブハウス・ホール}}
      *{{category 東京}}

      !!リンク
      *[オフィシャルサイト|http://www.loft-prj.co.jp/schedule/loft/]

      !住所
      *東京都新宿区西新宿1-12-9 スタジオアルタ横B2F
      *[[MAP:東京都新宿区西新宿1-12-9]]

      !最寄り駅等
      *JR新宿駅
    WIKI

    venue = import(id: 1, name: '新宿ロフト', wiki: wiki)

    assert_equal '新宿ロフト', venue.name
    assert_equal 'シンジュクロフト', venue.name_kana
    assert_equal '東京都', venue.prefecture
    assert_equal '東京都新宿区西新宿1-12-9 スタジオアルタ横B2F', venue.address
    assert venue.live_house?
    assert venue.active?
    assert_equal ['http://www.loft-prj.co.jp/schedule/loft/'], venue.links.map(&:url)
  end

  test '改名履歴（旧名 → 新名）を name_log に記録する' do
    wiki = <<~WIKI
      !!!{{rb 新宿FUTURE NATURE VALVE,シンジュクフューチャーネイチャーバルブ}} → 新宿FNV
      *{{category ライブハウス・ホール}}

      !住所
      *東京都新宿区新宿5-4-1
    WIKI

    venue = import(id: 2, name: '新宿FUTURE NATURE VALVE', wiki: wiki)

    assert_equal '新宿FNV', venue.name
    assert_equal [
      { 'name' => '新宿FUTURE NATURE VALVE', 'name_kana' => 'シンジュクフューチャーネイチャーバルブ' },
      { 'name' => '新宿FNV', 'name_kana' => nil }
    ], venue.name_log
  end

  test '先頭の一覧リンク行があっても見出し行から名称を取り込む' do
    wiki = <<~WIKI
      [[ライブハウス・ホール一覧]]
      !!!マリンメッセ福岡（マリンメッセフクオカ）
      *{{category ライブハウス・ホール}}
      *{{category 九州}}

      !住所
      *福岡市博多区沖浜町7-1
    WIKI

    venue = import(id: 3, name: 'マリンメッセ福岡', wiki: wiki)

    assert_equal 'マリンメッセ福岡', venue.name
    assert_equal 'マリンメッセフクオカ', venue.name_kana
    assert_equal '福岡市博多区沖浜町7-1', venue.address
    assert_nil venue.prefecture
  end

  test '読みが空の括弧表記（名称（）)でも名称のみ取り込む' do
    wiki = <<~WIKI
      [[ライブハウス・ホール一覧]]
      !!!宮崎SR（）
      *{{category ライブハウス・ホール}}
    WIKI

    venue = import(id: 4, name: '宮崎SR', wiki: wiki)

    assert_equal '宮崎SR', venue.name
    assert_nil venue.name_kana
  end

  test 'キャパシティが記載されていれば取り込む' do
    wiki = <<~WIKI
      !!!テストホール（テストホール）
      *{{category ライブハウス・ホール}}

      !!キャパシティ
      *350
    WIKI

    venue = import(id: 5, name: 'テストホール', wiki: wiki)

    assert_equal 350, venue.capacity
  end

  test 'キャパシティが不明（?）で後続セクションが空の場合、以降のセクションの数字を誤って取り込まない' do
    wiki = <<~WIKI
      !!!大分DRUM Be-0（ドラム ビーゼロ）
      *{{category ライブハウス・ホール}}

      !住所
      *大分県大分市金池町2-13-20

      !最寄り駅等
      *JR大分駅(正面出口より徒歩5分)

      !!キャパシティ
      *?

      !!備考


      !!情報
      *キャパシティ３５０人 - 名無し (2012年01月11日 13時16分08秒)
      {{comment}}
    WIKI

    venue = import(id: 7, name: '大分DRUM Be-0', wiki: wiki)

    assert_nil venue.capacity
    assert_equal '大分県大分市金池町2-13-20', venue.address
    assert_equal '大分県', venue.prefecture
  end

  test '住所セクションの直後が空セクションの場合、以降のセクションの内容を住所に含めない' do
    wiki = <<~WIKI
      !!!テスト会場（テストカイジョウ）
      *{{category ライブハウス・ホール}}

      !住所
      *仙台市青葉区国分町3-3-7

      !最寄り駅等


      !!備考
      1,590席

      !!情報
      *宮城県から東京都に移転しました - 名無しさん
      {{comment}}
    WIKI

    venue = import(id: 8, name: 'テスト会場', wiki: wiki)

    assert_equal '仙台市青葉区国分町3-3-7', venue.address
    assert_nil venue.prefecture
  end

  test '同じ old_key で再実行しても重複作成されない' do
    wiki = <<~WIKI
      !!!再取り込みテスト（サイトリコミテスト）
      *{{category ライブハウス・ホール}}
    WIKI

    first = import(id: 6, name: '再取り込みテスト', wiki: wiki)
    second = import(id: 6, name: '再取り込みテスト', wiki: wiki)

    assert_equal first.id, second.id
    assert_equal 1, Venue.where(old_wiki_id: 6).count
  end
end
