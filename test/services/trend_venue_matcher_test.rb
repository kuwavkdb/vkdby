# frozen_string_literal: true

require 'test_helper'

class TrendVenueMatcherTest < ActiveSupport::TestCase
  def create_venue(key, name, **attrs)
    Venue.create!(key:, name:, **attrs)
  end

  def match(title, content = title)
    TrendVenueMatcher.new.match(Trend.new(title:, content:))
  end

  test 'タイトル末尾の括弧（素のテキスト・Wikiリンク）が会場名に一致すれば紐付け対象にする' do
    venue = create_venue('ikebukuro-cyber', '池袋CYBER')

    [match('解散(池袋CYBER)'), match('解散([[池袋CYBER]])')].each do |result|
      assert_equal :matched, result.status
      assert_equal :title_trailing, result.source
      assert_equal [venue.id], result.venue_ids
    end
  end

  test '[[表示|リンク先]] はリンク先でも一致する' do
    venue = create_venue('lan-akasaka', 'L@N AKASAKA')

    result = match('加入([[赤坂L@N|L@N AKASAKA]])')

    assert_equal :matched, result.status
    assert_equal [venue.id], result.venue_ids
  end

  test '改名前の名前（name_log）・別名（aliases）・旧Wikiページ名（old_key）でも一致する' do
    venue = create_venue('tsutaya-o-west', 'TSUTAYA O-WEST',
                         name_log: [{ 'name' => 'Shibuya O-West' }, { 'name' => 'TSUTAYA O-WEST' }],
                         aliases: [{ 'name' => 'O-WEST' }],
                         old_key: URI.encode_www_form_component('渋谷O-WEST'.encode('EUC-JP')))

    ['Shibuya O-West', 'O-WEST', '渋谷O-WEST'].each do |name|
      assert_equal [venue.id], match("解散(#{name})").venue_ids, name
    end
  end

  test '末尾以外のタイトル中の括弧に会場があれば紐付け対象にする' do
    venue = create_venue('takadanobaba-area', '高田馬場AREA')

    result = match('活動終了([[高田馬場AREA]]) → [[ViViD]]')

    assert_equal :matched, result.status
    assert_equal :title_parenthetical, result.source
    assert_equal [venue.id], result.venue_ids
  end

  test '本文の2行目以降にだけ会場リンクがある場合は自動では紐付けず要確認にする' do
    venue = create_venue('ikebukuro-blackhole', '池袋BlackHole')

    result = match('Gu.U-sk 正式加入', "Gu.U-sk 正式加入\n**正式加入後の初ライブは11/08([[池袋BlackHole]])")

    assert_equal :review, result.status
    assert_equal [venue.id], result.venue_ids
  end

  test '人名などのWikiリンクは会場名として扱わない' do
    create_venue('zepp-tokyo', 'Zepp Tokyo')

    result = match('Ba.[[Jasmine You]] 体調不良')

    assert_equal :none, result.status
  end

  test '同じ名前の会場が複数ある場合は候補複数にする' do
    create_venue('holiday-osaka', 'HOLIDAY OSAKA')
    create_venue('ash-osaka', 'Ash OSAKA', name_log: [{ 'name' => 'HOLIDAY OSAKA' }, { 'name' => 'Ash OSAKA' }])

    result = match('解散([[HOLIDAY OSAKA]])')

    assert_equal :ambiguous, result.status
    assert_equal 2, result.venue_ids.size
  end

  test 'タイトル末尾の括弧に複数の会場が書かれている場合は候補複数にする' do
    create_venue('ikebukuro-cyber', '池袋CYBER')
    create_venue('esaka-muse', 'ESAKA MUSE')

    result = match('2日復活([[池袋CYBER]]、[[ESAKA MUSE]])')

    assert_equal :ambiguous, result.status
  end

  test '末尾の括弧が会場に一致しなければ一致なしとして名前を返す' do
    create_venue('ikebukuro-cyber', '池袋CYBER')

    result = match('地上波放送(テレビ東京)')

    assert_equal :unmatched, result.status
    assert_equal ['テレビ東京'], result.names
  end

  test '括弧も会場リンクもなければ会場名なしにする' do
    assert_equal :none, match('活動休止').status
  end

  test '論理削除した会場とは突き合わせない' do
    create_venue('ikebukuro-cyber', '池袋CYBER').discard

    assert_equal :unmatched, match('解散(池袋CYBER)').status
  end
end
