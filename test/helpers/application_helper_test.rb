# frozen_string_literal: true

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper
  include ActiveSupport::Testing::TimeHelpers
  include ViewComponent::TestHelpers

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

  test 'リスト項目中のHTMLコメントはエスケープされず生のHTMLコメントとして出力される（Issue#1116）' do
    result = markdown("- 通常の項目\n- <!-- TODO: 要手動対応 元記法: {{category イベント}} -->\n- 別の項目")

    assert_no_match(/&lt;!--/, result)
    assert_match(/<!-- TODO: 要手動対応 元記法: \{\{category イベント\}\} -->/, result)
    assert_match(/通常の項目/, result)
    assert_match(/別の項目/, result)
  end

  test '文中のHTMLコメントはエスケープされず生のHTMLコメントとして出力される（Issue#1116）' do
    result = markdown('前の文<!-- 隠しコメント -->後の文')

    assert_no_match(/&lt;!--/, result)
    assert_match(/前の文<!-- 隠しコメント -->後の文/, result)
  end

  test '行頭単独のHTMLコメントは従来どおり生HTMLコメントとして出力される' do
    result = markdown("本文\n\n<!-- 行頭コメント -->\n\n続き")

    assert_match(/<!-- 行頭コメント -->/, result)
  end

  test 'HTMLコメント内のプラグイン記法は展開されずコメントごとそのまま残る（Issue#1116）' do
    result = markdown('<!-- {{unknown foo,bar}} -->')

    assert_match(/<!-- \{\{unknown foo,bar\}\} -->/, result)
  end

  test '{{snapshot key,id}}で公開スナップショットのメンバーが埋め込まれる' do
    unit = Unit.create!(key: 'snapshot-plugin-unit', name: 'テストユニット', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー', part: :vocal, status: :active)

    result = markdown("{{snapshot #{unit.key},#{snapshot.id}}}")

    assert_match(/テストメンバー/, result)
  end

  test '{{snapshot}}はcurrent: trueのスナップショットでも、ユニットページ本体と違い初期状態は折りたたまれている' do
    unit = Unit.create!(key: 'snapshot-plugin-unit-current-fold', name: 'テストユニット', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー', part: :vocal, status: :active)

    result = markdown("{{snapshot #{unit.key},#{snapshot.id}}}")

    assert_match(/data-toggle-open-value="false"/, result)
  end

  test 'ユニットページ本体(summary_preview: true)では従来どおりcurrent: trueのスナップショットが初期展開される' do
    unit = Unit.create!(key: 'unit-page-current-open', name: 'テストユニット', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー', part: :vocal, status: :active)

    result = render_inline(UnitSnapshotsComponent.new(snapshots: [snapshot], unit: unit)).to_html

    assert_match(/data-toggle-open-value="true"/, result)
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
    # 露出していないこと（<p>の中にdata-toggle-target等の属性テキストが漏れていないこと）を確認する
    assert_no_match(/<p>[^<]*data-toggle-target/, result)
    assert_match(/テストメンバー4/, result)
  end

  test '{{snapshot}}で埋め込んだ過去スナップショットはユニットページ本体と異なり、1行プレビュー(summary)を出さずメンバー一覧をその場で表示する' do
    unit = Unit.create!(key: 'snapshot-plugin-unit5', name: 'テストユニット5', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: false, active: true)
    snapshot.snapshot_people.create!(person_name: 'テストメンバー5', part: :vocal, status: :active)

    result = markdown("{{snapshot #{unit.key},#{snapshot.id}}}")

    # 1行プレビュー(summary)・hx-get遅延取得は使われない
    assert_no_match(/data-toggle-target="summary/, result)
    assert_no_match(/hx-get/, result)
    # {{div_begin class="members"}}と同じく、メンバー一覧は開閉に関わらず常に表示される
    assert_match(/data-toggle-target="area"/, result)
    assert_match(/テストメンバー5/, result)
  end

  test '{{snapshot key}}でsnapshot_idを省略した場合はcurrent: trueのスナップショットが埋め込まれる（issue #1136）' do
    unit = Unit.create!(key: 'snapshot-plugin-unit-omit-id', name: 'テストユニット', status: 'active')
    unit.unit_snapshots.create!(snapshot_date: '2019-01-01', current: false, active: true).tap do |s|
      s.snapshot_people.create!(person_name: '過去メンバー', part: :vocal, status: :active)
    end
    current_snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
    current_snapshot.snapshot_people.create!(person_name: '現在メンバー', part: :vocal, status: :active)

    result = markdown("{{snapshot #{unit.key}}}")

    assert_match(/現在メンバー/, result)
    assert_no_match(/過去メンバー/, result)
  end

  test '{{snapshot key}}でcurrent: trueのスナップショットが存在しない場合は空文字になる' do
    unit = Unit.create!(key: 'snapshot-plugin-unit-omit-id-none', name: 'テストユニット', status: 'active')
    unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: false, active: true).tap do |s|
      s.snapshot_people.create!(person_name: '過去メンバー2', part: :vocal, status: :active)
    end

    result = markdown("前{{snapshot #{unit.key}}}後")

    assert_match(/前後/, result)
    assert_no_match(/過去メンバー2/, result)
  end

  test '{{snapshot key}}でcurrent: trueのスナップショットが非公開(active: false)の場合は空文字になる' do
    unit = Unit.create!(key: 'snapshot-plugin-unit-omit-id-inactive', name: 'テストユニット', status: 'active')
    snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: false)
    snapshot.snapshot_people.create!(person_name: '非公開メンバー', part: :vocal, status: :active)

    result = markdown("前{{snapshot #{unit.key}}}後")

    assert_match(/前後/, result)
    assert_no_match(/非公開メンバー/, result)
  end

  test '{{snapshot key}}でユニットkeyが存在しない場合は空文字になる' do
    result = markdown('前{{snapshot no-such-unit}}後')

    assert_match(/前後/, result)
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

  test '{{youtube 動画ID}}でYouTube動画が埋め込まれる' do
    result = markdown('{{youtube C-PqwPsrDd0}}')

    assert_match(%r{https://www\.youtube\.com/embed/C-PqwPsrDd0}, result)
    assert_match(/<iframe/, result)
  end

  test '{{youtube 動画ID}}で複数行タグが崩れずに埋め込まれる' do
    result = markdown("前\n\n{{youtube C-PqwPsrDd0}}\n\n後")

    assert_no_match(/<p>[^<]*<iframe/, result)
    assert_match(/<iframe/, result)
  end

  test '{{youtube 動画ID}}で動画IDの形式が不正な場合は空文字になる' do
    result = markdown('前{{youtube ../../etc}}後')

    assert_match(/前後/, result)
    assert_no_match(/<iframe/, result)
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

  test '{{div_begin class="members"}}はユニットページのMembersセクションと同じ外枠(toggleコントローラ・角丸カード)で出力される' do
    result = markdown(<<~MARKDOWN)
      {{div_begin class="members"}}

      {{member2 Bass,森川泰敬
      → [GLAMOROUS HONEY](/glamorous-honey)
      }}

      {{div_end}}
    MARKDOWN

    assert_match(/<section data-controller="toggle" data-toggle-open-value="false">/, result)
    assert_match(/role="heading" aria-level="2"[^>]*>Members</, result)
    assert_match(/data-action="click->toggle#toggle"/, result)
    assert_match(/rounded-2xl overflow-hidden shadow-sm" data-toggle-target="area"/, result)
    assert_match(%r{</section>}, result)
    assert_match(/森川泰敬/, result)
    assert_match(/GLAMOROUS HONEY/, result)
  end

  test '{{div_begin class="members"}}はユニットページのMembersセクションと同様、メンバー一覧自体は開閉に関わらず常に表示される' do
    result = markdown(<<~MARKDOWN)
      {{div_begin class="members"}}

      {{member2 Bass,森川泰敬
      → [GLAMOROUS HONEY](/glamorous-honey)
      }}

      {{div_end}}
    MARKDOWN

    # 初期状態(閉)はメンバーごとの経歴表示のみが非表示になり、メンバー一覧自体は表示される
    assert_match(/data-toggle-open-value="false"/, result)
    assert_no_match(/data-toggle-target="summary/, result)
    assert_match(/森川泰敬/, result)
  end

  test '空行区切りなしで連続する{{member}}は<p>や<br>で余分に囲まれない(Issue#1130の余白崩れ対策)' do
    Person.create!(name: 'のる', key: 'members-gap-person-1',
                   old_key: URI.encode_www_form_component('のる(ex-ふりぃ)'.encode('EUC-JP')))
    Person.create!(name: 'Kyoki', key: 'members-gap-person-2',
                   old_key: URI.encode_www_form_component('叶唏'.encode('EUC-JP')))

    result = markdown(<<~MARKDOWN)
      {{div_begin class="members"}}
      {{member Vocal,のる,のる(ex-ふりぃ)}}
      {{member Guitar,Kyoki,叶唏}}
      {{div_end}}
    MARKDOWN

    # 各メンバー行(ブロック要素)が<p>で囲まれたり、行間に<br>が挟まったりしていないこと
    assert_no_match(/<p>\s*<(?:section|div)/, result)
    assert_no_match(%r{</div>\s*<br>}, result)
    assert_no_match(%r{</div>\s*</p>}, result)
    assert_match(/のる/, result)
    assert_match(/Kyoki/, result)
  end

  test '{{div_begin class="members" subject="..."}}は見出しラベルを上書きできる' do
    result = markdown('{{div_begin class="members" subject="旧メンバー"}}本文{{div_end}}')

    assert_match(/role="heading" aria-level="2"[^>]*>旧メンバー</, result)
    assert_no_match(/role="heading" aria-level="2"[^>]*>Members</, result)
  end

  test '{{div_begin class="members"}}のsubject値はHTMLエスケープされる' do
    result = markdown('{{div_begin class="members" subject="a&b"}}本文{{div_end}}')

    assert_match(/role="heading" aria-level="2"[^>]*>a&amp;b</, result)
  end

  test '{{div_begin class="members"}}の見出しは<h2>ではなくrole="heading"のdivを使う(markdown-content内の意図しない下線対策)' do
    result = markdown('{{div_begin class="members"}}本文{{div_end}}')

    assert_no_match(/<h2/, result)
  end

  test '{{div_begin class="members"}}のネストで対応する{{div_end}}が</div></section>を出力する' do
    result = markdown(<<~MARKDOWN)
      {{div_begin class="members"}}

      {{div_begin class="inner"}}

      本文

      {{div_end}}

      {{div_end}}
    MARKDOWN

    assert_match(/<section data-controller="toggle"/, result)
    assert_match(/<div class="inner">/, result)
    assert_match(%r{</section>}, result)
  end

  test '{{div_begin class="columns"}}は画像や{{youtube}}埋め込みを左右に並べるための<div class="columns">を出力する' do
    result = markdown(<<~MARKDOWN)
      {{div_begin class="columns"}}
      ![説明](https://example.com/image.jpg)

      {{youtube C-PqwPsrDd0}}
      {{div_end}}
    MARKDOWN

    assert_match(/<div class="columns">/, result)
    assert_match(%r{<img[^>]+src="https://example.com/image.jpg"}, result)
    assert_match(%r{<iframe src="https://www.youtube.com/embed/C-PqwPsrDd0"}, result)
  end

  test '{{member パート,表示名,old_key}}でold_keyに一致するPersonの経歴カードが埋め込まれる' do
    Person.create!(name: 'のる', key: 'member-plugin-person',
                   old_key: URI.encode_www_form_component('のる(ex-ふりぃ)'.encode('EUC-JP')))

    result = markdown('{{member Vocal,のる,のる(ex-ふりぃ)}}')

    assert_match(/のる/, result)
    assert_match(%r{href="/member-plugin-person"}, result)
  end

  test '{{member}}のメンバー名は<h3>ではなくrole="heading"のdivを使う(markdown-content内の意図しない余白対策)' do
    Person.create!(name: 'のる', key: 'member-plugin-person-noh3',
                   old_key: URI.encode_www_form_component('のる(ex-ふりぃ)'.encode('EUC-JP')))

    result = markdown('{{member Vocal,のる,のる(ex-ふりぃ)}}')

    assert_no_match(/<h3/, result)
    assert_match(/role="heading" aria-level="3"/, result)
  end

  test '{{member}}は表示名(第2引数)をそのまま表示し、Personのnameとは独立している' do
    Person.create!(name: 'DB上の名前', key: 'member-plugin-person2',
                   old_key: URI.encode_www_form_component('旧名'.encode('EUC-JP')))

    result = markdown('{{member Vocal,表示用の名前,旧名}}')

    assert_match(/表示用の名前/, result)
    assert_no_match(/DB上の名前/, result)
  end

  test '{{member}}で一致するPersonが見つからない場合、old_key未指定と同様プロフィールリンクなしで表示される(Issue#1152)' do
    result = markdown('{{member Vocal,のる,存在しないキー}}')

    assert_match(/のる/, result)
    assert_no_match(%r{<a[^>]*>のる</a>}, result)
  end

  test '{{member}}はold_keyが"-"（未指定）の場合、Personへのリンクなしで表示名・リンクのみ表示する(Issue#1132)' do
    result = markdown('{{member Vocal,相馬 ジュン平,-,http://smjp.jugem.jp/}}')

    assert_match(/相馬 ジュン平/, result)
    assert_match(%r{href="http://smjp.jugem.jp/"}, result)
    assert_no_match(%r{<a[^>]*>相馬 ジュン平</a>}, result)
  end

  test '{{member}}はold_key自体を省略した場合も同様にPersonへのリンクなしで表示される(Issue#1132)' do
    result = markdown('{{member Vocal,相馬 ジュン平}}')

    assert_match(/相馬 ジュン平/, result)
  end

  test '{{member}}はステータスバッジを表示しない' do
    Person.create!(name: 'のる', key: 'member-plugin-person3',
                   old_key: URI.encode_www_form_component('のる3'.encode('EUC-JP')))

    result = markdown('{{member Vocal,のる,のる3}}')

    assert_no_match(/undefined/, result)
  end

  test '{{member パート,表示名,old_key,リンク}}の4番目のパラメータがURLの場合はそのままリンクになる' do
    Person.create!(name: 'のる', key: 'member-plugin-person-url',
                   old_key: URI.encode_www_form_component('のる5'.encode('EUC-JP')))

    result = markdown('{{member Vocal,のる,のる5,http://example.com/noru}}')

    assert_match(%r{href="http://example.com/noru"}, result)
  end

  test '{{member パート,表示名,old_key,リンク}}の4番目のパラメータが@始まりの場合はXアカウントとして扱われる' do
    Person.create!(name: 'のる', key: 'member-plugin-person-x',
                   old_key: URI.encode_www_form_component('のる6'.encode('EUC-JP')))

    result = markdown('{{member Vocal,のる,のる6,@noru_xxx}}')

    assert_match(%r{href="https://x.com/noru_xxx"}, result)
  end

  test '{{member2}}はold_keyが一致しない場合、複数行のdataをメンバー自身の経歴として出力する' do
    result = markdown(<<~MARKDOWN)
      {{member2 Bass,森川泰敬
      → [GLAMOROUS HONEY](/glamorous-honey){{fn 2006/05/10加入}}
      }}
    MARKDOWN

    assert_match(/森川泰敬/, result)
    assert_match(/GLAMOROUS HONEY/, result)
    assert_match(%r{href="/glamorous-honey"}, result)
    assert_match(%r{2006/05/10加入}, result)
  end

  test '{{member2}}はCRLF改行の本文でも複数行ブロックとして正しく終端を検出する(Issue#1132)' do
    # Windows由来の貼り付け等でCRLFが混じると、"}}"直後が\rになり$にマッチしなくなり、
    # 複数行ブロックの終端を見失って表示が崩れていた（実際のCustomPage本文で発覚）。
    md = "{{member2 Bass,森川泰敬\r\n→ [GLAMOROUS HONEY](/glamorous-honey){{fn 2006/05/10加入}}\r\n}}\r\n"
    result = markdown(md)

    assert_match(/森川泰敬/, result)
    assert_match(/GLAMOROUS HONEY/, result)
    assert_match(%r{2006/05/10加入}, result)
    assert_no_match(/\}\}/, result)
  end

  test '{{member2}}はブロック内にネストした{{fn ...}}を終端の"}}"と誤認しない' do
    result = markdown(<<~MARKDOWN)
      前

      {{member2 Bass,森川泰敬
      → [GLAMOROUS HONEY](/glamorous-honey){{fn 2006/05/10加入}}
      、[別ユニット](/other-unit)
      }}

      後
    MARKDOWN

    assert_match(/前/, result)
    assert_match(/後/, result)
    assert_match(/別ユニット/, result)
  end

  test '{{member2}}はold_keyが一致するPersonが見つかればmemberプラグインと同様にそのPersonの経歴を出力する' do
    Person.create!(name: 'のる', key: 'member2-plugin-person',
                   old_key: URI.encode_www_form_component('のる(ex-ふりぃ)'.encode('EUC-JP')))

    result = markdown(<<~MARKDOWN)
      {{member2 Vocal,のる,のる(ex-ふりぃ)
      この行はold_key一致時には使われない
      }}
    MARKDOWN

    assert_match(%r{href="/member2-plugin-person"}, result)
    assert_no_match(/この行はold_key一致時には使われない/, result)
  end

  test '{{member2}}はold_key省略時、常にdataをメンバー自身の経歴として扱う' do
    result = markdown(<<~MARKDOWN)
      {{member2 Guitar,テストギタリスト
      [別ユニット2](/other-unit2)
      }}
    MARKDOWN

    assert_match(/テストギタリスト/, result)
    assert_match(/別ユニット2/, result)
  end

  test '{{member2 パート,表示名,old_key}}（1行・dataなし）はmemberプラグイン相当として動作する' do
    Person.create!(name: 'のる', key: 'member2-plugin-person-inline',
                   old_key: URI.encode_www_form_component('のる4'.encode('EUC-JP')))

    result = markdown('{{member2 Vocal,のる,のる4}}')

    assert_match(%r{href="/member2-plugin-person-inline"}, result)
  end

  test '{{member2 パート,表示名,old_key,リンク}}（4番目のパラメータ）はold_keyの一致有無にかかわらずリンクを表示する' do
    result = markdown(<<~MARKDOWN)
      {{member2 Bass,泉,泉(ex-蟋蟀),http://ameblo.jp/bass-izumi/
      → [蟋蟀](/koorogi) → 個人/フリー
      }}
    MARKDOWN

    assert_match(%r{href="http://ameblo.jp/bass-izumi/"}, result)
    assert_match(/蟋蟀/, result)
  end

  test '{{member2}}の4番目のパラメータが@始まりの場合はXアカウントとして扱われる' do
    result = markdown(<<~MARKDOWN)
      {{member2 Bass,泉,泉(ex-蟋蟀),@bass_izumi
      → [蟋蟀](/koorogi) → 個人/フリー
      }}
    MARKDOWN

    assert_match(%r{href="https://x.com/bass_izumi"}, result)
  end

  test '{{member2}}のold_keyが"-"（未指定）の場合はPersonを検索せずdataを経歴として扱う' do
    result = markdown(<<~MARKDOWN)
      {{member2 Guitar,神谷 英希,-
      → [くりから。](/kurikara)(一期) → (隠密華撃団) → [くりから。](/kurikara)(二期) →
      }}
    MARKDOWN

    assert_match(/神谷 英希/, result)
    assert_match(/くりから。/, result)
    assert_match(/隠密華撃団/, result)
  end

  test '{{member2}}はold_key・リンクを省略した複数行ブロックの手前に単独行の{{member2}}があっても巻き込まない(Issue#1133)' do
    Person.create!(name: 'K.', key: 'member2-regression-guitar',
                   old_key: URI.encode_www_form_component('K.'.encode('EUC-JP')))

    result = markdown(<<~MARKDOWN)
      {{member2 Guitar,K.,K.}}

      {{member2 Bass,森川泰敬
      → [GLAMOROUS HONEY](/glamorous-honey){{fn 2006/05/10加入}}
      }}
    MARKDOWN

    assert_match(%r{href="/member2-regression-guitar"}, result)
    assert_match(/森川泰敬/, result)
    assert_match(/GLAMOROUS HONEY/, result)
    assert_no_match(/\}\}/, result)
  end

  # 以下、issue #1115（プラグインのcache対応）関連のテスト。
  # test環境のデフォルトcache_storeは:null_store（常にブロックを実行し何もキャッシュしない）
  # のため、キャッシュの有無を検証するテストのみ一時的にMemoryStoreへ差し替える。
  def with_memory_cache_store
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end

  test '{{item}}はキャッシュされ、updated_atが変わらない更新には反応しない' do
    with_memory_cache_store do
      item = Item.create!(title: '初期タイトル', release_date: '2020-01-01',
                          link_url: 'https://example.com/item/cache1', asin: 'B00CACHEITEM1')

      first = markdown("{{item #{item.asin}}}")
      assert_match(/初期タイトル/, first)

      # updated_atを変えずにDBだけ書き換える（キャッシュキーは変化しないはず）
      item.update_column(:title, '書き換え後タイトル')

      second = markdown("{{item #{item.asin}}}")
      assert_match(/初期タイトル/, second, 'キャッシュキーが同じなら初回レンダリング結果が再利用されるはず')
    end
  end

  test '{{item}}はItemが更新されるとキャッシュが自動的に切り替わる' do
    with_memory_cache_store do
      item = Item.create!(title: '初期タイトル2', release_date: '2020-01-01',
                          link_url: 'https://example.com/item/cache2', asin: 'B00CACHEITEM2')
      markdown("{{item #{item.asin}}}")

      travel(1.second) { item.update!(title: '更新後タイトル2') }

      result = markdown("{{item #{item.asin}}}")
      assert_match(/更新後タイトル2/, result)
    end
  end

  test '{{member}}はPersonが更新されるとキャッシュが自動的に切り替わる' do
    with_memory_cache_store do
      person = Person.create!(name: 'のる', key: 'member-cache-person',
                              old_key: URI.encode_www_form_component('cache-key-1'.encode('EUC-JP')),
                              old_history: '旧履歴テキスト')

      first = markdown('{{member Vocal,のる,cache-key-1}}')
      assert_match(/旧履歴テキスト/, first)

      travel(1.second) { person.update!(old_history: '新履歴テキスト') }

      second = markdown('{{member Vocal,のる,cache-key-1}}')
      assert_match(/新履歴テキスト/, second)
      assert_no_match(/旧履歴テキスト/, second)
    end
  end

  test '{{snapshot}}はsnapshot_peopleの編集で親unit_snapshotがtouchされキャッシュが切り替わる' do
    with_memory_cache_store do
      unit = Unit.create!(key: 'snapshot-cache-unit', name: 'キャッシュテストユニット', status: 'active')
      snapshot = unit.unit_snapshots.create!(snapshot_date: '2020-01-01', current: true, active: true)
      sp = snapshot.snapshot_people.create!(person_name: '旧メンバー名', part: :vocal, status: :active)

      first = markdown("{{snapshot #{unit.key},#{snapshot.id}}}")
      assert_match(/旧メンバー名/, first)

      travel(1.second) { sp.update!(person_name: '新メンバー名') }

      second = markdown("{{snapshot #{unit.key},#{snapshot.id}}}")
      assert_match(/新メンバー名/, second)
      assert_no_match(/旧メンバー名/, second)
    end
  end

  # 以下、issue #1215（markdown本文内画像のCLS・LCP対策）関連のテスト。
  test 'Active Storageのblobリダイレクトを指す画像は、blobのmetadata(width/height)からwidth/height属性が付与される(issue #1215)' do
    blob = create_image_blob(width: 400, height: 150)

    result = markdown("![alt](#{rails_blob_path(blob, only_path: true)})")

    assert_match(/<img[^>]+width="400"[^>]+height="150"/, result)
  end

  test 'blobのmetadataにwidth/heightが記録されていない場合はwidth/height属性を付与しない(issue #1215)' do
    blob = create_image_blob(width: nil, height: nil)

    result = markdown("![alt](#{rails_blob_path(blob, only_path: true)})")

    assert_no_match(/width=/, result)
    assert_no_match(/height=/, result)
  end

  test 'Active Storage以外の外部URL画像はwidth/height属性を付与しない(issue #1215)' do
    result = markdown('![alt](https://example.com/image.jpg)')

    assert_no_match(/width=/, result)
    assert_no_match(/height=/, result)
  end

  test '解析未完了(width/height無し)の結果はキャッシュされず、後から解析が完了すれば反映される(issue #1215)' do
    with_memory_cache_store do
      blob = create_image_blob(width: nil, height: nil)
      src = rails_blob_path(blob, only_path: true)

      before = markdown("![alt](#{src})")
      assert_no_match(/width=/, before)

      # rakeタスク(active_storage:analyze_images)相当: 後からmetadataが埋まるケース
      blob.update!(metadata: blob.metadata.merge('width' => 400, 'height' => 150))

      after = markdown("![alt](#{src})")
      assert_match(/<img[^>]+width="400"[^>]+height="150"/, after)
    end
  end

  test 'prioritize_first_image: true の場合、本文最初の画像のみfetchpriority="high"が付与される(issue #1215)' do
    blob = create_image_blob(width: 400, height: 150)
    src = rails_blob_path(blob, only_path: true)

    result = markdown("![1つ目](#{src})\n\n![2つ目](#{src})", prioritize_first_image: true)

    images = result.scan(/<img[^>]*>/)
    assert_equal 2, images.size
    assert_match(/fetchpriority="high"/, images[0])
    assert_no_match(/fetchpriority/, images[1])
  end

  test 'prioritize_first_imageを指定しない場合はfetchpriorityを付与しない(issue #1215)' do
    blob = create_image_blob(width: 400, height: 150)

    result = markdown("![alt](#{rails_blob_path(blob, only_path: true)})")

    assert_no_match(/fetchpriority/, result)
  end

  test 'meta_content_textはHTML属性値として引用符や不等号をエスケープする' do
    result = meta_content_text(%(Title "quoted" <b>&amp;</b>))

    assert_equal 'Title &quot;quoted&quot; &lt;b&gt;&amp;&lt;/b&gt;', result
  end

  test 'meta_content_textはmeta_description_textと違い160字で切り詰めない（issue #1253）' do
    long_text = 'あ' * 200

    result = meta_content_text(long_text)

    assert_equal 200, result.length
  end

  test 'og_image_urlはconfig.site_ogp_image_pathをrequest.base_urlに連結した絶対URLを返す（issue #1253）' do
    result = og_image_url

    assert_equal "http://test.host#{Rails.application.config.site_ogp_image_path}", result
  end

  private

  def create_image_blob(width:, height:)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('dummy'),
      filename: 'test.png',
      content_type: 'image/png'
    )
    metadata = blob.metadata.merge('identified' => true, 'analyzed' => true)
    metadata['width'] = width if width
    metadata['height'] = height if height
    blob.update!(metadata: metadata)
    blob
  end
end
