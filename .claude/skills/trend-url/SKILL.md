---
name: trend-url
description: 記事のURLやXのポストを渡すと、内容を読み取って管理画面のTrend作成画面（/admin/trends/new）を事前入力するURLを生成する。動向を登録したいネタのURLを受け取ったときに使う。
---

## 目的

ARGUMENTS（または会話中）で渡された **記事URL / Xのポストの URL** から動向情報を抽出し、管理画面の Trend 作成画面を事前入力した状態で開ける URL を出力する（issue #1582）。

- 生成するだけで **Trend の保存はしない**。管理者が画面で内容を確認し、ユニット・個人を選んで保存する
- 本番 DB には触れない。ユニット・個人の ID は URL に入れず、名前のテキストだけを渡す（管理画面のサジェストで人が確定する）

## URL の形式

```
https://www.vkdb.jp/admin/trends/new?<パラメーター>
```

ローカルで確認したい場合は `http://localhost:3000/admin/trends/new?...` に読み替える。パラメーターの値は必ず URL エンコードする（`ruby -ruri -e` や `python3 -c 'import urllib.parse'` で組み立ててよい）。

| パラメーター | 内容 |
| --- | --- |
| `trend[date]` | 出来事の日付。`YYYY-MM-DD` |
| `trend[day_unknown]` / `trend[month_unknown]` | 日・月が不明なら `1`。不明な部分は `01` で仮埋めする |
| `trend[title]` | 件名（後述の書式） |
| `trend[content]` | 本文。title と同じ内容か、短い要約 |
| `trend[quote]` | 引用文。Xのポストは oEmbed の HTML、記事は必要なら本文の抜粋 |
| `trend[quote_url]` | 引用元 URL（Xのポスト URL / 記事 URL） |
| `trend[via_name]` / `trend[via_url]` | 情報元名・URL。直近のデータでは空のことが多いので、必要なときだけ |
| `trend[unit_phenomenon]` / `trend[person_phenomenon]` / `trend[etc_phenomenon]` | 動向種別のキー文字列。存在しないキーは無視される |
| `unit_name` | ユニット名（テキスト入力欄に表示されるだけ。サジェストで確定するのは人） |
| `person_name` | 個人名（同上） |

複数のユニット・個人は扱わない。主となる 1 件だけを `unit_name` / `person_name` に入れ、残りは管理画面で追加してもらう。
`publish_start_at` や `active` などは URL からは設定できない（無視される）。

## 手順

1. **内容を取得する**
   - 記事: WebFetch で取得する
   - Xのポスト: WebFetch はログイン壁で失敗しやすい。次の順に試す
     1. `https://publish.twitter.com/oembed?omit_script=1&url=<ポストURL>` を取得する。返ってくる `html` は既存データの `quote` と同じ形式（`<blockquote class="twitter-tweet">…`）なので、そのまま `trend[quote]` に使う
     2. ダメなら chrome-devtools MCP でポストを開いて本文を読む
     3. それもダメならユーザーに本文の貼り付けを依頼する
   - `quote_url` は既存データに合わせて `twitter.com/...` 形式を使う（`x.com` で渡された場合は `twitter.com` に読み替える）
2. **動向を抽出する**
   - 対象がユニット（バンド）か個人か、名前、出来事、日付を読み取る
   - 日付は **出来事の日付**。記事の公開日・ポストの投稿日と一致するとは限らない（「◯月◯日をもって」など本文を確認する）。読み取れない部分は `day_unknown` / `month_unknown` を立てる
   - 動向種別は `app/models/trend.rb` の enum（`unit_phenomenon` / `person_phenomenon` / `etc_phenomenon`）と `config/locales` の日本語ラベルを読み、当てはまるキーを 1 つ選ぶ。迷ったら `other`。ユニットの動向ならユニット側、メンバーの動向なら個人側の種別にする
3. **URL を組み立てる**
   - 情報の根拠が読み取れなかった項目は、推測で埋めずに空のままにする
4. **出力する**
   - 生成した URL を 1 つ提示する
   - 抽出した内容（対象・日付・動向種別・title）を箇条書きで添え、日付や種別など判断に迷った点があれば明記する

## title の書式

既存データの規約に合わせる。

- メンバーの動向: `<パート>.<名前> <出来事>`（例: `Gu.一輝 脱退`、`Dr. J 'ω'2 脱退`、`YAIRI 死去`）
- サイト内に個人ページがある場合は wiki リンク `[[表記|名前]]` を使う（例: `Vo. [[Amon|天聞]] 引退`）。ページの有無が分からなければリンクにしない
- 会場が分かるライブ・活動休止などは末尾に `(会場)`（例: `Gu.一輝 活動休止(SHIBUYA DESEO)`、`＜手毬、源 依織、Ivy、Syu＞新バンド 1st.LIVE([[高田馬場CLUB PHASE]])`）
- 複数メンバーは `＜A、B、C＞` でまとめる

## 注意

- 記事本文をそのまま `content` / `quote` に転載しない。`content` は事実を短くまとめる。`quote` に入れるのは X の oEmbed HTML か、必要最小限の抜粋にとどめる
- URL が長くなりすぎる（目安 2000 文字超）場合は `quote` を URL から外し、`quote_url` だけ渡して「引用文は手で貼ってください」と伝える
- 未ログインで開くとログイン画面に遷移する。ログイン後に開き直してもらう
