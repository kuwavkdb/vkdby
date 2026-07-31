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

class PersonTest < ActiveSupport::TestCase # rubocop:disable Metrics/ClassLength
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

  test 'parse_old_history captures trailing role text after wiki link' do
    # [[バンド名]]ローディー のように括弧なしで役割テキストが続く場合
    person = Person.new(old_history: '[[ザアザア]]ローディー → [[OLD CIRCUS]]')
    history = person.parse_old_history

    assert_equal 2, history.size
    assert_equal 'ザアザア', history[0][0][:unit_name]
    assert_equal 'ローディー', history[0][0][:part_and_name]
    assert_equal 'OLD CIRCUS', history[1][0][:unit_name]
    assert_nil history[1][0][:part_and_name]
  end

  test 'parse_old_history captures parenthesized role after wiki link' do
    # [[バンド名]](サポート) 形式
    person = Person.new(old_history: '[[バンドA]](サポート) → [[バンドB]]')
    history = person.parse_old_history

    assert_equal 2, history.size
    assert_equal 'バンドA', history[0][0][:unit_name]
    assert_equal 'サポート', history[0][0][:part_and_name]
    assert_equal 'バンドB', history[1][0][:unit_name]
    assert_nil history[1][0][:part_and_name]
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

  test 'parse_old_history double-encodes apostrophe in band name for old_key' do
    # アポストロフィ(')はURI.encode_www_form_componentで%27としてDBに保存される
    # Railsのルーティングは%27を'にデコードするため、%2527に二重エンコードする必要がある
    # （%2527 → Railsデコード → %27 → DBのold_keyと一致）
    person = Person.new(old_history: "[[Develop One's Faculties]]")
    history = person.parse_old_history

    assert_equal 1, history.size
    item = history[0][0]
    assert_equal "Develop One's Faculties", item[:unit_name]
    # '(0x27)は%2527に二重エンコード
    assert_equal '%44%65%76%65%6C%6F%70+%4F%6E%65%2527%73+%46%61%63%75%6C%74%69%65%73', item[:old_key]
  end

  test 'key uniqueness is case-insensitive' do
    Person.create!(name: 'Existing Person', key: 'case-key-test', status: :active)
    person = Person.new(name: 'Duplicate Person', key: 'Case-Key-Test', status: :active)

    assert_not person.valid?
    assert_includes person.errors[:key], 'はすでに存在します'
  end

  test 'change_key! raises when new key duplicates an existing key by case only' do
    Person.create!(name: 'Existing Person', key: 'case-change-target', status: :active)
    person = Person.create!(name: 'Renaming Person', key: 'person-key-change-case-before', status: :active)

    assert_raises(ActiveRecord::RecordInvalid) do
      person.change_key!('Case-Change-Target')
    end
  end

  test 'change_key! raises when new key duplicates a discarded redirect stub by case only' do
    person = Person.create!(name: 'Rename Target Person', key: 'person-key-stub-before', status: :active)
    person.change_key!('person-key-stub-after')
    other = Person.create!(name: 'Other Person', key: 'person-key-stub-other', status: :active)

    assert_raises(ActiveRecord::RecordInvalid) do
      other.change_key!('Person-Key-Stub-Before')
    end
  end

  test 'change_key! updates the key and creates a discarded redirect stub' do
    person = Person.create!(name: 'Rename Target Person', key: 'person-key-change-before', status: :active)

    person.change_key!('person-key-change-after')

    assert_equal 'person-key-change-after', person.reload.key

    stub = Person.discarded.find_by(key: 'person-key-change-before')
    assert stub.present?
    assert stub.discarded?
    assert_equal 'person-key-change-after', stub.destination_key
    assert_nil stub.old_key
  end

  test 'change_key! rewrites snapshot_people.person_key and unit_people.person_key' do
    person = Person.create!(name: 'Referenced Person', key: 'person-ref-key-before', status: :active)
    unit = Unit.create!(name: 'Host Unit', key: 'person-ref-host-unit', status: :active)
    snapshot = unit.unit_snapshots.create!(snapshot_date: Date.current, current: true)
    snapshot_person = snapshot.snapshot_people.create!(person_key: 'person-ref-key-before', person_name: 'x', sort_order: 1)
    unit_person = UnitPerson.create!(unit: unit, person_key: 'person-ref-key-before')

    person.change_key!('person-ref-key-after')

    assert_equal 'person-ref-key-after', snapshot_person.reload.person_key
    assert_equal 'person-ref-key-after', unit_person.reload.person_key
  end

  test 'change_key! rewrites items.artists referencing the previous key' do
    person = Person.create!(name: 'Artist Person', key: 'person-artist-key-before', status: :active)
    item = Item.create!(title: 'Artist Item', release_date: Date.current, link_url: 'https://example.com/person-artist-item',
                        artists: [{ 'name' => 'Artist Person', 'key' => 'person-artist-key-before' }])

    person.change_key!('person-artist-key-after')

    assert_equal 'person-artist-key-after', item.reload.artists.first['key']
  end

  test 'unpublished? is false without an unpublished tag' do
    person = Person.create!(name: 'Untagged Person', key: 'person-untagged', status: :active)

    assert_not person.unpublished?
  end

  test 'unpublished? is true when tagged with a configured unpublished tag id' do
    person = Person.create!(name: 'Unpublished Person', key: 'person-unpublished', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    assert person.unpublished?
  end

  test 'published scope excludes persons tagged with a configured unpublished tag id' do
    published_person = Person.create!(name: 'Published Person', key: 'person-published-scope', status: :active)
    unpublished_person = Person.create!(name: 'Unpublished Person', key: 'person-unpublished-scope', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: unpublished_person)

    assert_includes Person.published, published_person
    assert_not_includes Person.published, unpublished_person
  end
end
