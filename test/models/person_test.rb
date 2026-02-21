# frozen_string_literal: true

# == Schema Information
#
# Table name: people
#
#  id            :bigint           not null, primary key
#  birth_year    :integer
#  birthday      :date
#  blood         :string
#  hometown      :string
#  key           :string
#  name          :string
#  name_kana     :string
#  name_log      :jsonb
#  note          :text
#  old_history   :text
#  old_key       :string
#  old_wiki_text :text
#  parts         :json
#  status        :integer          default("active"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  old_wiki_id   :integer
#
# Indexes
#
#  index_people_on_key        (key) UNIQUE
#  index_people_on_name       (name)
#  index_people_on_name_kana  (name_kana)
#  index_people_on_old_key    (old_key) UNIQUE
#
require 'test_helper'

class PersonTest < ActiveSupport::TestCase
  test 'parse_old_history parses simple history' do
    person = Person.new(old_history: 'BandA → BandB')
    history = person.parse_old_history

    assert_equal 2, history.size
    assert_equal 'BandA', history[0][0][:unit_name]
    assert_equal 'BandB', history[1][0][:unit_name]
  end

  test 'parse_old_history parses concurrent memberships' do
    person = Person.new(old_history: 'BandA → BandB、BandC → BandD')
    history = person.parse_old_history

    assert_equal 3, history.size

    # First period
    assert_equal 1, history[0].size
    assert_equal 'BandA', history[0][0][:unit_name]

    # Second period (concurrent)
    assert_equal 2, history[1].size
    assert_equal 'BandB', history[1][0][:unit_name]
    assert_equal 'BandC', history[1][1][:unit_name]

    # Third period
    assert_equal 1, history[2].size
    assert_equal 'BandD', history[2][0][:unit_name]
  end

  test 'parse_old_history parses complex formats with links and parens' do
    # [[Sadie]](Mao)、[[The THIRTEEN]](Mao)、[[Frantic EMIRY|Frantic EMIRY]](Rem.)
    # Note: Using escaped brackets for the test string as it would be in DB
    history_str = '[[Sadie]](Mao)、[[The THIRTEEN]](Mao)、[[Frantic EMIRY|Frantic EMIRY]](Rem.)'
    person = Person.new(old_history: history_str)
    history = person.parse_old_history

    assert_equal 1, history.size
    concurrent = history[0]
    assert_equal 3, concurrent.size

    assert_equal 'Sadie', concurrent[0][:unit_name]
    assert_equal 'Mao', concurrent[0][:part_and_name]

    assert_equal 'The THIRTEEN', concurrent[1][:unit_name]
    assert_equal 'Mao', concurrent[1][:part_and_name]

    assert_equal 'Frantic EMIRY', concurrent[2][:unit_name]
    assert_equal 'Rem.', concurrent[2][:part_and_name]
  end

  test 'parse_old_history handles parens wrapping correctly' do
    person = Person.new(old_history: '(Solo) → (BandA)')
    history = person.parse_old_history

    assert_equal 2, history.size
    assert_equal '(Solo)', history[0][0][:unit_name]
    assert_equal '(BandA)', history[1][0][:unit_name] # Current logic keeps parens if not matching link pattern?
    # Let's check the implementation logic:
    # wrapped_in_parens = segment.start_with?('(') && segment.end_with?(')')
    # content = wrapped_in_parens ? segment[1..-2] : segment
    # Else block: concurrent_items << { unit_name: item_segment.strip } -> using ORIGINAL item_segment

    # Wait, the implementation says:
    # Pattern 3: Plain text - No link, display as-is (including parentheses)
    # else
    #   concurrent_items << {
    #     unit_name: item_segment.strip
    #   }

    # So (Solo) should result in unit_name: "(Solo)"
    assert_equal '(Solo)', history[0][0][:unit_name]
  end

  test 'parse_old_history does not split arrow inside parentheses' do
    # (C.F.Randle→輝喜) は名前変更を意味するため、経歴の区切りではない
    history_str = '[[feathers-blue]](輝喜) → [[アンティック-珈琲店-]](C.F.Randle→輝喜) → [[NextBand]]'
    person = Person.new(old_history: history_str)
    history = person.parse_old_history

    assert_equal 3, history.size

    assert_equal 'feathers-blue', history[0][0][:unit_name]
    assert_equal '輝喜', history[0][0][:part_and_name]

    assert_equal 'アンティック-珈琲店-', history[1][0][:unit_name]
    assert_equal 'C.F.Randle→輝喜', history[1][0][:part_and_name]

    assert_equal 'NextBand', history[2][0][:unit_name]
  end

  test 'parse_old_history does not split comma inside braces (fn plugin)' do
    # {{fn 2010/06/13、2010/06/18~2011/06/26}} 内の、は区切りではない
    history_str = '[[アンティック-珈琲店-]]、[[DOGinTheパラレルワールドオーケストラ]](サポート){{fn 2010/06/13、2010/06/18~2011/06/26}}、他サポート多数'
    person = Person.new(old_history: history_str)
    history = person.parse_old_history

    assert_equal 1, history.size
    concurrent = history[0]
    assert_equal 3, concurrent.size

    assert_equal 'アンティック-珈琲店-', concurrent[0][:unit_name]

    assert_equal 'DOGinTheパラレルワールドオーケストラ', concurrent[1][:unit_name]
    assert_equal 'サポート', concurrent[1][:part_and_name]
    assert_equal ['2010/06/13、2010/06/18~2011/06/26'], concurrent[1][:notes]

    assert_equal '他サポート多数', concurrent[2][:unit_name]
  end

  test 'parse_old_history encodes space in band name as plus sign for old_key' do
    # DBのold_keyはスペースが+で保存されるため、+でエンコードされることを確認
    person = Person.new(old_history: '[[BULL ZEICHEN 88]]')
    history = person.parse_old_history

    assert_equal 1, history.size
    item = history[0][0]
    assert_equal 'BULL ZEICHEN 88', item[:unit_name]
    # スペースは+に変換される（DBのold_keyフォーマットに合わせる）
    assert_equal '%42%55%4C%4C+%5A%45%49%43%48%45%4E+%38%38', item[:old_key]
  end
end
