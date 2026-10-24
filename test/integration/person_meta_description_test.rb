# frozen_string_literal: true

require 'test_helper'

# 個人のページのmeta description（issue #1938, #1945, #1951）
class PersonMetaDescriptionTest < ActionDispatch::IntegrationTest
  def meta_description
    css_select('meta[name="description"]').first['content']
  end

  test '今の所属（経歴の最後の期間）とパート、過去の在籍バンドを経歴の新しい順に書く' do
    person = Person.create!(name: 'Meta Person', name_kana: 'メタパーソン', key: 'meta-person', status: :active,
                            parts: %w[vocal guitar], birthday: Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), hometown: '東京都',
                            old_history: '[[Meta Old]] → [[Meta Left]](Gt) → [[Meta Current]]、[[Meta Current Two]]')

    get profile_path(person.key)

    assert_equal 'Meta Person（メタパーソン）はMeta Current、Meta Current Twoのボーカル・ギター。' \
                 '過去の在籍バンドはMeta Left、Meta Old。経歴や在籍バンド、音源等を掲載。', meta_description
    assert_equal meta_description, css_select('meta[property="og:description"]').first['content']
  end

  test 'スナップショットに在籍として残っていても、経歴に無ければ今の所属に書かない' do
    person = Person.create!(name: 'Meta Stale', key: 'meta-stale', status: :unknown, parts: %w[guitar],
                            old_history: '[[Meta Old]] → ([[Meta Session]]) → {{category 個人/状況不明}}')
    Unit.create!(name: 'Meta Session', key: 'meta-session', status: :active)
        .unit_snapshots.create!(current: true).snapshot_people.create!(person:, part: :guitar, sort_order: 1)

    get profile_path(person.key)

    assert_equal 'Meta Staleはギター。過去の在籍バンドはMeta Old。経歴や在籍バンド、音源等を掲載。', meta_description
  end

  test '経歴が「→」で終わる人は今の所属なしとし、最後の期間も過去の在籍バンドに含める' do
    person = Person.create!(name: 'Meta Arrow', key: 'meta-arrow', status: :active, parts: %w[bass],
                            old_history: "[[Meta First]] → [[Meta Last]] →\n// [[Meta Comment]]")

    get profile_path(person.key)

    assert_equal 'Meta Arrowはベース。過去の在籍バンドはMeta Last、Meta First。経歴や在籍バンド、音源等を掲載。', meta_description
  end

  test '今の所属・過去の在籍バンドは、リンクの無い項目・括弧で囲んだ項目・ソロ・サポートを除き、同じ名前は新しい位置で1回だけ書く' do
    person = Person.create!(name: 'Meta History', key: 'meta-history', status: :active,
                            old_history: "[[Meta First]] → [[Meta Again]] → ソロ → ([[Meta Session]]) → [[Meta Support]](サポート) → \n" \
                                         "// [[Meta Comment]] →\n" \
                                         '[Meta Link](/meta-link)、[[Meta Concurrent]] → [[ソロ|Meta History]] → ' \
                                         '[[META AGAIN]](Ba) → [[meta now]] → ソロ、[[Meta Now]]、([[Meta Project]])、[[Meta Help]](サポート)')

    get profile_path(person.key)

    assert_equal 'Meta HistoryはMeta Nowのメンバー。過去の在籍バンドはMETA AGAIN、Meta Link、Meta Concurrent、Meta First。' \
                 '経歴や在籍バンド、音源等を掲載。', meta_description
  end

  test 'パートが無い人は、所属があれば「メンバー」、無ければ「アーティスト」とする' do
    member = Person.create!(name: 'Meta No Part', key: 'meta-no-part', status: :active, old_history: '[[Meta Band]]')
    artist = Person.create!(name: 'Meta Nothing', key: 'meta-nothing', status: :active)

    get profile_path(member.key)
    assert_equal 'Meta No PartはMeta Bandのメンバー。経歴や在籍バンド、音源等を掲載。', meta_description

    get profile_path(artist.key)
    assert_equal 'Meta Nothingはアーティスト。経歴や在籍バンド、音源等を掲載。', meta_description
  end

  test '過去の在籍バンドが多いときは160字に収まる件数だけ並べて「他」とし、締めの文を残す' do
    person = Person.create!(name: 'Meta Many Units', key: 'meta-many-units', status: :active, parts: %w[bass],
                            old_history: "#{Array.new(30) { |i| "[[過去のバンド#{i.to_s.rjust(2, '0')}]]" }.join(' → ')} →")

    get profile_path(person.key)

    description = meta_description
    assert_operator description.length, :<=, 160
    assert description.start_with?('Meta Many Unitsはベース。過去の在籍バンドは過去のバンド29、過去のバンド28、')
    assert description.end_with?('他。経歴や在籍バンド、音源等を掲載。')
  end

  test '今の所属が多いときも160字に収まる件数だけ並べて「他」とし、締めの文を残す' do
    person = Person.create!(name: 'Meta Many Current', key: 'meta-many-current', status: :active, parts: %w[guitar],
                            old_history: Array.new(20) { |i| "[[今のバンド#{i.to_s.rjust(2, '0')}]]" }.join('、'))

    get profile_path(person.key)

    description = meta_description
    assert_operator description.length, :<=, 160
    assert description.start_with?('Meta Many Currentは今のバンド00、今のバンド01、')
    assert description.end_with?('他のギター。経歴や在籍バンド、音源等を掲載。')
  end

  test '引退した人は今の所属を書かず、最後の期間も過去の在籍バンドとして経歴の新しい順に並べる' do
    person = Person.create!(name: 'Meta Retired', key: 'meta-retired', status: :retirement, parts: %w[guitar],
                            old_history: '[[Meta Earlier]] → [[Meta Still Listed]]')

    get profile_path(person.key)

    assert_equal 'Meta Retiredはギター。過去の在籍バンドはMeta Still Listed、Meta Earlier。経歴や在籍バンド、音源等を掲載。',
                 meta_description
  end

  test '死去した人は最後に在籍したバンドのメンバーとして書く' do
    person = Person.create!(name: 'Meta Passed', key: 'meta-passed', status: :passed_away, parts: %w[drums],
                            old_history: '[[Meta Earlier Band]] → [[Meta Last Band]] → {{category 死去}}')

    get profile_path(person.key)

    assert_equal 'Meta PassedはMeta Last Bandのドラム。過去の在籍バンドはMeta Earlier Band。経歴や在籍バンド、音源等を掲載。',
                 meta_description
  end

  test '非公開の個人はサイト共通の説明文のままにする' do
    person = Person.create!(name: 'Meta Unpublished Person', key: 'meta-unpublished-person', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get profile_path(person.key)

    assert_equal Rails.application.config.site_description, meta_description
  end
end
