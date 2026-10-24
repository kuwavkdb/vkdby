# frozen_string_literal: true

require 'test_helper'

# 個人のページのmeta description（issue #1938）
class PersonMetaDescriptionTest < ActionDispatch::IntegrationTest
  def meta_description
    css_select('meta[name="description"]').first['content']
  end

  def add_member(person, unit, snapshot_date:, current: false, **attributes)
    unit.unit_snapshots.create!(snapshot_date:, current:)
        .snapshot_people.create!(person:, part: :vocal, sort_order: 1, **attributes)
  end

  test '今の所属とパート、過去の在籍バンドを新しい順に書き、サポート・関係者・非公開のユニットは含めない' do
    person = Person.create!(name: 'Meta Person', name_kana: 'メタパーソン', key: 'meta-person', status: :active,
                            parts: %w[vocal guitar], birthday: Date.new(Person::DUMMY_BIRTH_YEAR, 7, 12), hometown: '東京都')
    add_member(person, Unit.create!(name: 'Meta Current', key: 'meta-current', status: :active),
               snapshot_date: Date.new(2024, 1, 1), current: true)
    add_member(person, Unit.create!(name: 'Meta Old', key: 'meta-old', status: :disbanded),
               snapshot_date: Date.new(2010, 1, 1), current: true)
    add_member(person, Unit.create!(name: 'Meta Left', key: 'meta-left', status: :active),
               snapshot_date: Date.new(2018, 1, 1), current: true, status: :left)
    add_member(person, Unit.create!(name: 'Meta Support', key: 'meta-support', status: :active),
               snapshot_date: Date.new(2020, 1, 1), current: true, support: true)
    hidden_unit = Unit.create!(name: 'Meta Hidden', key: 'meta-hidden', status: :disbanded)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: hidden_unit)
    add_member(person, hidden_unit, snapshot_date: Date.new(2015, 1, 1), current: true)

    get profile_path(person.key)

    assert_equal 'Meta Person（メタパーソン）はMeta Currentのボーカル・ギター。過去の在籍バンドはMeta Left、Meta Old。' \
                 '経歴や在籍バンド、音源等を掲載。', meta_description
    assert_equal meta_description, css_select('meta[property="og:description"]').first['content']
  end

  test '今の所属が無い人はパートと過去の在籍バンドを書く' do
    person = Person.create!(name: 'Meta Former', key: 'meta-former', status: :retirement, parts: %w[drums])
    add_member(person, Unit.create!(name: 'Meta Disbanded', key: 'meta-disbanded', status: :disbanded),
               snapshot_date: Date.new(2010, 1, 1), current: true)

    get profile_path(person.key)

    assert_equal 'Meta Formerはドラム。過去の在籍バンドはMeta Disbanded。経歴や在籍バンド、音源等を掲載。', meta_description
  end

  test 'パートが無い人は、所属があれば「メンバー」、無ければ「アーティスト」とする' do
    member = Person.create!(name: 'Meta No Part', key: 'meta-no-part', status: :active)
    add_member(member, Unit.create!(name: 'Meta Band', key: 'meta-band-for-person', status: :active),
               snapshot_date: Date.new(2024, 1, 1), current: true)
    artist = Person.create!(name: 'Meta Nothing', key: 'meta-nothing', status: :active)

    get profile_path(member.key)
    assert_equal 'Meta No PartはMeta Bandのメンバー。経歴や在籍バンド、音源等を掲載。', meta_description

    get profile_path(artist.key)
    assert_equal 'Meta Nothingはアーティスト。経歴や在籍バンド、音源等を掲載。', meta_description
  end

  test '過去の在籍バンドが多いときは160字に収まる件数だけ並べて「他」とし、締めの文を残す' do
    person = Person.create!(name: 'Meta Many Units', key: 'meta-many-units', status: :active, parts: %w[bass])
    30.times do |i|
      add_member(person, Unit.create!(name: "過去のバンド#{i.to_s.rjust(2, '0')}", key: "meta-past-#{i}", status: :disbanded),
                 snapshot_date: Date.new(2000 + i, 1, 1), current: true)
    end

    get profile_path(person.key)

    description = meta_description
    assert_operator description.length, :<=, 160
    assert description.start_with?('Meta Many Unitsはベース。過去の在籍バンドは過去のバンド29、過去のバンド28、')
    assert description.end_with?('他。経歴や在籍バンド、音源等を掲載。')
  end

  test '今の所属が多いときも160字に収まる件数だけ並べて「他」とし、締めの文を残す' do
    person = Person.create!(name: 'Meta Many Current', key: 'meta-many-current', status: :active, parts: %w[guitar])
    20.times do |i|
      add_member(person, Unit.create!(name: "今のバンド#{i.to_s.rjust(2, '0')}", key: "meta-current-#{i}", status: :active),
                 snapshot_date: Date.new(2024, 1, 1), current: true)
    end

    get profile_path(person.key)

    description = meta_description
    assert_operator description.length, :<=, 160
    assert description.start_with?('Meta Many Currentは今のバンド')
    assert description.end_with?('他のギター。経歴や在籍バンド、音源等を掲載。')
  end

  test '引退した人は今の所属を書かず、今の所属だったユニットも過去の在籍バンドとして新しい順に並べる' do
    person = Person.create!(name: 'Meta Retired', key: 'meta-retired', status: :retirement, parts: %w[guitar])
    add_member(person, Unit.create!(name: 'Meta Still Listed', key: 'meta-still-listed', status: :active),
               snapshot_date: Date.new(2020, 1, 1), current: true)
    add_member(person, Unit.create!(name: 'Meta Earlier', key: 'meta-earlier', status: :disbanded),
               snapshot_date: Date.new(2010, 1, 1), current: true)

    get profile_path(person.key)

    assert_equal 'Meta Retiredはギター。過去の在籍バンドはMeta Still Listed、Meta Earlier。経歴や在籍バンド、音源等を掲載。',
                 meta_description
  end

  test '死去した人は最後に在籍したバンドのメンバーとして書く' do
    person = Person.create!(name: 'Meta Passed', key: 'meta-passed', status: :passed_away, parts: %w[drums])
    add_member(person, Unit.create!(name: 'Meta Last Band', key: 'meta-last-band', status: :active),
               snapshot_date: Date.new(2020, 1, 1), current: true)

    get profile_path(person.key)

    assert_equal 'Meta PassedはMeta Last Bandのドラム。経歴や在籍バンド、音源等を掲載。', meta_description
  end

  test '過去の在籍バンドの日付が同じ・無いときはユニットのid順に並べる' do
    person = Person.create!(name: 'Meta Same Date', key: 'meta-same-date', status: :active)
    units = %w[B A C].map do |suffix|
      Unit.create!(name: "Meta Same #{suffix}", key: "meta-same-#{suffix.downcase}", status: :disbanded)
    end
    units.first(2).each { |unit| add_member(person, unit, snapshot_date: Date.new(2015, 1, 1), current: true) }
    add_member(person, units.last, snapshot_date: nil, current: true)

    get profile_path(person.key)

    assert_includes meta_description, '過去の在籍バンドはMeta Same B、Meta Same A、Meta Same C。'
  end

  test '非公開の個人はサイト共通の説明文のままにする' do
    person = Person.create!(name: 'Meta Unpublished Person', key: 'meta-unpublished-person', status: :active)
    tag_index = TagIndex.create!(id: Rails.application.config.unpublished_tag_ids.first, name: '掲載停止')
    TagIndexItem.create!(tag_index: tag_index, indexable: person)

    get profile_path(person.key)

    assert_equal Rails.application.config.site_description, meta_description
  end
end
