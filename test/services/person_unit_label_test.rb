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
