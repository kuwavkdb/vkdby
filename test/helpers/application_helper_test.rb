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

  test '{{item ASIN}}でItemカードが埋め込まれる' do
    item = Item.create!(title: 'テストアルバム', release_date: '2020-01-01',
                        link_url: 'https://example.com/item/1', asin: 'B00TESTASIN')

    result = markdown("{{item #{item.asin}}}")

    assert_match(/テストアルバム/, result)
  end

  test '{{item ASIN}}で複数行タグが崩れずに埋め込まれる' do
    item = Item.create!(title: 'テストアルバム2', release_date: '2020-01-01',
                        link_url: 'https://example.com/item/2', asin: 'B00TESTASIN2')

    result = markdown("前\n\n{{item #{item.asin}}}\n\n後")

    # ItemCardComponentの複数行タグの属性がRedcarpetに解析されテキストとして
    # 露出していないこと（<p>の中にdata-controller等の属性テキストが漏れていないこと）を確認する
    assert_no_match(/<p>[^<]*data-controller/, result)
    assert_match(/data-controller="item-card-artists"/, result)
    assert_match(/テストアルバム2/, result)
  end

  test '{{item ASIN}}でASINが未登録の場合は空文字になる' do
    result = markdown('前{{item B00NOSUCHASIN}}後')

    assert_match(/前後/, result)
  end

  test '{{div_begin class="..."}}と{{div_end}}でdivタグが出力される' do
    result = markdown(<<~MARKDOWN)
      {{div_begin class="closable"}}

      本文

      {{div_end}}
    MARKDOWN

    assert_match(/<div class="closable">/, result)
    assert_match(%r{</div>}, result)
    assert_match(/本文/, result)
  end

  test '{{div_begin}}（属性なし）はclass属性なしのdivタグを出力する' do
    result = markdown('{{div_begin}}本文{{div_end}}')

    assert_match(/<div>/, result)
    assert_no_match(/class=/, result)
  end

  test '{{div_begin}}はclass以外の属性を無視する（属性インジェクション対策）' do
    result = markdown('{{div_begin onclick="alert(1)"}}本文{{div_end}}')

    assert_no_match(/onclick/, result)
  end

  test '{{div_begin class="..."}}のclass値はHTMLエスケープされる' do
    result = markdown('{{div_begin class="a&b"}}本文{{div_end}}')

    assert_match(/class="a&amp;b"/, result)
  end

  test '{{div_begin class="closable" subject="..."}}は折りたたみ(details/summary)で出力される' do
    result = markdown(<<~MARKDOWN)
      {{div_begin class="closable" subject="メンバー"}}

      本文

      {{div_end}}
    MARKDOWN

    assert_match(/<details class="closable">/, result)
    assert_match(%r{<summary>メンバー</summary>}, result)
    assert_match(%r{</details>}, result)
    assert_no_match(%r{</div>}, result)
    # 初期状態は折りたたみ（open属性なし）であること
    assert_no_match(/<details[^>]*\bopen\b/, result)
  end

  test 'subject指定でもclass="closable"がなければ通常のdivのまま(折りたたみにならない)' do
    result = markdown('{{div_begin subject="メンバー"}}本文{{div_end}}')

    assert_no_match(/<details/, result)
    assert_no_match(/summary/, result)
    assert_match(/<div>/, result)
  end

  test '{{div_begin class="closable" subject="..."}}のsubject値はHTMLエスケープされる' do
    result = markdown('{{div_begin class="closable" subject="a&b"}}本文{{div_end}}')

    assert_match(%r{<summary>a&amp;b</summary>}, result)
  end

  test '{{div_begin}}のネストで対応する{{div_end}}が正しいタグを閉じる' do
    result = markdown(<<~MARKDOWN)
      {{div_begin class="closable" subject="外側"}}

      {{div_begin class="inner"}}

      本文

      {{div_end}}

      {{div_end}}
    MARKDOWN

    assert_match(/<details class="closable">/, result)
    assert_match(/<div class="inner">/, result)
    assert_match(%r{</div>}, result)
    assert_match(%r{</details>}, result)
  end

  test '{{member パート,表示名,old_key}}でold_keyに一致するPersonの経歴カードが埋め込まれる' do
    Person.create!(name: 'のる', key: 'member-plugin-person',
                   old_key: URI.encode_www_form_component('のる(ex-ふりぃ)'.encode('EUC-JP')))

    result = markdown('{{member Vocal,のる,のる(ex-ふりぃ)}}')

    assert_match(/のる/, result)
    assert_match(%r{href="/member-plugin-person"}, result)
  end

  test '{{member}}は表示名(第2引数)をそのまま表示し、Personのnameとは独立している' do
    Person.create!(name: 'DB上の名前', key: 'member-plugin-person2',
                   old_key: URI.encode_www_form_component('旧名'.encode('EUC-JP')))

    result = markdown('{{member Vocal,表示用の名前,旧名}}')

    assert_match(/表示用の名前/, result)
    assert_no_match(/DB上の名前/, result)
  end

  test '{{member}}で一致するPersonが見つからない場合は空文字になる' do
    result = markdown('前{{member Vocal,のる,存在しないキー}}後')

    assert_match(/前後/, result)
  end

  test '{{member}}はステータスバッジを表示しない' do
    Person.create!(name: 'のる', key: 'member-plugin-person3',
                   old_key: URI.encode_www_form_component('のる3'.encode('EUC-JP')))

    result = markdown('{{member Vocal,のる,のる3}}')

    assert_no_match(/undefined/, result)
  end
end
