# 会場データインポート仕様書

本書は Wikipage コンテンツから Venue（会場）データをインポートする際のフォーマット・ロジック・rake タスクの使い方について記述します（issue #1688）。

## 概要

`VenueImporter` サービスは、`{{category ライブハウス・ホール}}` を持つレガシーな Wikipage テキストを解析し、`Venue` レコードおよびその関連データ（`Link`）を作成または更新します。
`import:venues` rake タスクから実行します。

## 判定基準

以下を含む Wikipage は Venue とみなされます：
- `{{category ライブハウス・ホール}}`

## rake タスクの使い方

`bundle exec rails import:venues` で実行します（`wikipages` テーブルは読み取り専用のため、書き込みは `venues` / `links` / `wiki_page_imports` にのみ行われます）。

```bash
# dry-run: 対象件数とサンプル（名称・かな・住所・都道府県）を確認する。DBへの書き込みなし
DRY_RUN=1 bundle exec rails import:venues

# 本実行: 全件インポート
MODE=ALL bundle exec rails import:venues

# 手動仕訳済みページのみ（page_type=live_house かつ manually_set=true）
MODE=MANUAL bundle exec rails import:venues

# スキップ済みページを再処理（valid_venue? を再判定してインポート）
MODE=SKIPPED bundle exec rails import:venues

# インポート済みの全Venueを再取り込み（links を再作成）
MODE=RELOAD bundle exec rails import:venues

# パラメータ指定
ID=2043 bundle exec rails import:venues        # 特定IDのみ
LIMIT=10 MODE=ALL bundle exec rails import:venues  # 最大10件まで
```

**進め方の推奨**: まず `DRY_RUN=1` で対象件数・サンプルを確認し、問題なければ `MODE=ALL` で本実行する。

**再実行しても重複作成されない**: `old_key`（Wikipage名を EUC-JP エンコードしたもの）で既存 Venue を検索するため、同じ Wikipage を対象に再実行しても Venue が重複作成されることはない（既存レコードが更新される）。

## 会場名と改名履歴 (Name Log)

インポーターは Wiki コンテンツから、コメント行を除いて **最初に `!` で始まる行**（`!!!会場名（かな）` などの見出し行）を解析し、会場名・読み仮名・改名履歴を特定する。旧サイトでは見出し行の前に `[[ライブハウス・ホール一覧]]` のようなナビゲーションリンク行が入ることが多いため、単純な1行目ではなく見出し行を探す点が Unit/Person のインポーターと異なる。

### フォーマット
1. **履歴付きフォーマット**: `旧名称(かな) → 新名称(かな)`
   - 最後の要素が現在の Venue 名として使用される。
   - それより前の要素は `name_log` に保存される。
2. **シンプルフォーマット**: `名称(かな)`
3. **読みが空の表記**: `名称（）` のように括弧が空の場合、空括弧を除去したうえで名称のみを取り込む（かなは `nil`）。
4. **フォールバック**: 見出し行から名称が取れない場合は Wikipage のタイトルを使用する。

### サポートされる構文
- `{{rb 名称,かな}}`: ルビ構文
- `名称(かな)`: 丸括弧による読み仮名
- `[[表示名|リンク]]` または `[[リンク]]`: Wikiリンクは除去され、名称のみが抽出される

## キー生成 (Key Generation)

URLスラッグとなる `key` は、Unit と同じロジックで以下の優先順位で生成される：
1. ASCII Wiki名（該当する場合）
2. かな読みから変換されたローマ字
3. エンコードされた EUC-JP 文字列（ASCII/かな以外の場合のフォールバック）

キーは正規化される：
- 小文字化
- 英数字以外の文字（ハイフンを除く）を `-` に置換
- 重複がある場合は末尾に `-2`, `-3` などのサフィックスを付与

かなが取れない改名後の名称など、ローマ字化もできないケースでは EUC-JP エンコードした16進文字列がキーの元になり読みにくい `key` になることがある。この場合は取り込み後に管理画面で修正する。

## 所在地 (`prefecture` / `address`)

`!住所` または `!!住所` セクションの最初の行から抽出する。

- `address`: セクション最初の行をそのまま取り込む（Wikiリンクは除去）
- `prefecture`: `address` の抽出元テキストに `Venue::PREFECTURES` のいずれかが含まれていればそれを設定する。「東京」など正式名称でない表記や、都道府県名自体が省略された住所（例: `福岡市博多区...`）では `prefecture` は空欄のまま作成され、必要に応じて管理画面で修正する

## キャパシティ (`capacity`)

`!!キャパシティ` セクションから最初の数値を抽出する。セクションがない、または数値が見つからない場合は空欄のまま作成する（旧サイトでは明示されているページは一部のみ）。

## venue_type / status

- `venue_type` は常に `live_house`（既定値）で作成する。ホール・スタジオなど判別できるものも一律 `live_house` になるため、必要に応じて管理画面で修正する
- `status` は常に `active`（営業中）で作成する

## リンク (`Link`)

Unit と同じロジックで `!!リンク` セクションから解析される。

### フォーマット
- `[ラベル|URL]`: 汎用的な外部リンク
- `{{unlink ...}}`: 非アクティブ（リンク切れ/過去）のリンク

## 取り込み結果の記録 (`WikiPageImport`)

- インポートに成功した場合: `page_type: 'live_house'`, `status: 'imported'`, `import_target: Venue` で記録
- 名称が抽出できずインポートできなかった場合: `page_type: 'live_house'`, `status: 'skipped'`, `note: 'no venue name found'` で記録
