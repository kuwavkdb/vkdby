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

  test '{{snapshot key,id}}で公開スナップショットのメンバーが埋め込まれる' do
    unit = Unit.create!(key: 'snapshot-plugin-unit', name: 'テストユニット', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー', part: :vocal, status: :active)

    result = markdown("{{snapshot #{unit.key},#{snapshot.id}}}")

    assert_match(/テストメンバー/, result)
  end

  test '{{snapshot key,id}}で埋め込んだ場合はバンドページと違いラベルが表示されない' do
    unit = Unit.create!(key: 'snapshot-plugin-unit-label', name: 'テストユニット', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true,
                                           label: 'テストラベル')
    snapshot.snapshot_people.create!(person_name: 'テストメンバー', part: :vocal, status: :active)

    result = markdown("{{snapshot #{unit.key},#{snapshot.id}}}")

    assert_no_match(/テストラベル/, result)
  end

  test '{{snapshot}}でユニットkeyが存在しない場合は空文字になる' do
    unit = Unit.create!(key: 'snapshot-plugin-unit2', name: 'テストユニット2', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー2', part: :vocal, status: :active)

    result = markdown("前{{snapshot no-such-unit,#{snapshot.id}}}後")

    assert_match(/前後/, result)
    assert_no_match(/テストメンバー2/, result)
  end

  test '{{snapshot}}で別ユニットのsnapshot_idを指定した場合は空文字になる' do
    unit_a = Unit.create!(key: 'snapshot-plugin-unit-a', name: 'ユニットA', status: 'active')
    unit_b = Unit.create!(key: 'snapshot-plugin-unit-b', name: 'ユニットB', status: 'active')
    snapshot_b = unit_b.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    snapshot_b.snapshot_people.create!(person_name: 'ユニットBのメンバー', part: :vocal, status: :active)

    result = markdown("前{{snapshot #{unit_a.key},#{snapshot_b.id}}}後")

    assert_match(/前後/, result)
    assert_no_match(/ユニットBのメンバー/, result)
  end

  test '{{snapshot}}で非公開(active: false)スナップショットは空文字になる' do
    unit = Unit.create!(key: 'snapshot-plugin-unit3', name: 'テストユニット3', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: false)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー3', part: :vocal, status: :active)

    result = markdown("前{{snapshot #{unit.key},#{snapshot.id}}}後")

    assert_match(/前後/, result)
    assert_no_match(/テストメンバー3/, result)
  end

  test '{{snapshot}}で過去(current: false)スナップショットも複数行タグが崩れずに埋め込まれる' do
    unit = Unit.create!(key: 'snapshot-plugin-unit4', name: 'テストユニット4', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: false, active: true)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー4', part: :vocal, status: :active)

    result = markdown("前\n\n{{snapshot #{unit.key},#{snapshot.id}}}\n\n後")

    # UnitSnapshotsComponentの複数行タグの属性がRedcarpetに解析されテキストとして
    # 露出していないこと（<p>の中にhx-get等の属性テキストが漏れていないこと）を確認する
    assert_no_match(/<p>[^<]*(?:data-toggle-target|hx-get|hx-trigger)/, result)
    assert_match(%r{hx-get="[^"]*snapshots/#{snapshot.id}/members"}, result)
    assert_match(/テストメンバー4/, result)
  end
end
