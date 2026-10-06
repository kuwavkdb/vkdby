# frozen_string_literal: true

require 'test_helper'

class PersonUnitLabelTest < ActiveSupport::TestCase
  test '経歴が空ならnil' do
    assert_nil label(nil)
    assert_nil label('')
  end

  test '経歴に最後に書かれたユニット名を付ける' do
    assert_equal '黒夢', label('[[SADS]] → [[黒夢]]')
    assert_equal 'ソロ', label('[[黒夢]] → ソロ')
  end

  test '経歴の末尾に「→」があればex-を付ける' do
    assert_equal 'ex-黒夢', label("[[SADS]] → [[黒夢]] →\n")
  end

  test '最後のユニットの後に別の期間（ステータスタグのみなど）があればex-を付ける' do
    assert_equal 'ex-黒夢', label('[[黒夢]] → {{category 引退}}')
  end

  test '最後の期間に複数ある場合は先に書かれたもの' do
    assert_equal '黒夢', label('[[SADS]] → [[黒夢]]、[[SADS]]')
  end

  test '表示名は[[表示名|キー]]の表示名を使い、全体を囲む括弧とルビを除く' do
    assert_equal 'KUROYUME BAND', label('[[KUROYUME BAND|KUROYUME]]')
    assert_equal 'ex-黒夢', label('([[黒夢]]) →')
    assert_equal '黒夢', label('{{rb 黒夢,くろゆめ}}')
  end

  test 'サポートとしての在籍は除く（issue #1775）' do
    # 最後の期間がサポートだけなら、それより前の期間のユニットに ex- を付ける
    assert_equal 'ex-バンドA', label('[[バンドA]] → [[バンドB]](サポート)')
    assert_equal 'ex-バンドA', label('[[バンドA]] → [[バンドB]](Gu.サポート)、他サポート多数')
    assert_equal 'ex-バンドA', label('[[バンドA]] → [[バンドB]]サポート')
    # 同じ期間に正規の在籍とサポートがあれば正規の方
    assert_equal 'バンドA', label('[[バンドB]](サポート)、[[バンドA]]')
    # サポートしかなければ付けない
    assert_nil label('[[バンドB]](サポート)')
    # 外部リンク形式のサポート（実データ）
    assert_equal 'ex-Crazy★shampoo',
                 label('→ (ぷっちビジュ) → ([[Crazy★shampoo]]){{fn 2010/08加入}}→[[Crazy★shampoo]]{{fn 2012/09/04脱退}} → ' \
                       '[パンプキンストア|http://artist.aremond.net/pumpkinstore/](サポート){{fn 2014/08/28~}}')
  end

  test '//で始まるコメント行は末尾の「→」の判定に使わない' do
    assert_equal 'ソロ', label("ソロ\n// メモ →")
  end

  private

  def label(history)
    @person_seq = @person_seq.to_i + 1
    person = Person.new(name: "人物#{@person_seq}", old_history: history)
    PersonUnitLabel.new(person).call
  end
end
