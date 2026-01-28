# Wikipage Import Scripts

このディレクトリには、Wikipageデータをインポートするためのスクリプトが含まれています。

## スクリプト一覧

### 1. import_person.rb - 個人ページインポート

Wikipageから個人（Person）データをインポートします。

**使用方法**:
```bash
ID=15962 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails runner lib/tasks/import_person.rb
```

**インポート対象**:
- 名前・ふりがな（titleから）
- 誕生日・誕生年（categoryタグから）
- 血液型・出身地（categoryタグから）
- パート（categoryタグから）
- ステータス（引退、フリー、死去など）
- SNSリンク（`[[Twitter:account]]`など）
- 経歴（`!!経歴`セクション）

**条件**:
- `{{category 個人}}`が含まれるページのみインポート
- それ以外はスキップされます

**ステータス判定**（優先順位順）:
1. `{{category 死去}}` → `status: passed_away`
2. `{{category 引退}}` → `status: retirement`
3. `{{category 個人/フリー}}` → `status: free`
4. それ以外 → `status: active`

**Key生成**:
- ふりがな + 誕生日（MMDD形式）
- 例: `tomoya-1028`（トモヤ、10月28日生まれ）

### 2. import:units - ユニットデータ一括インポート

Wikipageからユニット（Unit）データを一括でインポートします。
`app/services/wikipage_importer.rb` を使用して処理されます。

**使用方法**:
```bash
# 全件インポート
bin/rails import:units

# パラメータ指定
ID=6555 bin/rails import:units       # 特定IDのみ
START=5000 bin/rails import:units    # ID 5000以降
LIMIT=10 bin/rails import:units      # 最大10件まで
```

**特徴**:
- `wikipages` テーブルの全レコード（または指定範囲）を走査します。
- メンバー情報（`{{member...}}` または `!Part...`）が含まれるページのみをインポート対象とします。
- 進捗状況とスキップ数を標準出力に表示します。

**インポート対象**:
- ユニット名・ふりがな
- メンバー情報（`{{member...}}`）
- SNSリンク
- ユニットタイプ（バンド、セッションなど）
- カテゴリ（TagIndex）


### 3. wikipage_parser.rb - 共通パーサーモジュール

両方のインポートスクリプトで使用される共通のパーサーロジック。

**モジュール**:
- `WikipageParser::LinkParser` - リンク解析
- `WikipageParser::CategoryParser` - カテゴリ解析
- `WikipageParser::Utils` - ユーティリティ（エンコーディング、キー生成）

## 対応リンクサービス

以下のサービスが`[[Service:Account]]`形式でサポートされています：

- Twitter / X
- YouTube Channel
- Spotify
- TikTok
- vk.gy
- JOYSOUND
- DAM / カラオケDAM
- digitlink
- Filmarks
- OTOTOY
- linkfire
- linktr.ee
- lnk.to

## データベーススキーマ

### People

| カラム | 型 | 説明 |
|--------|-----|------|
| name | string | 名前 |
| name_kana | string | ふりがな |
| key | string | URLキー（変更不可） |
| old_key | string | 旧vkdb.jpのキー（変更不可） |
| birthday | date | 誕生日（年は常に1904） |
| birth_year | integer | 実際の生まれ年 |
| blood | string | 血液型 |
| hometown | string | 出身地 |
| status | enum | ステータス |
| parts | json | パート（配列） |
| old_wiki_text | text | 元のwikiテキスト |
| old_history | text | 経歴セクション |

### Units

| カラム | 型 | 説明 |
|--------|-----|------|
| name | string | ユニット名 |
| name_kana | string | ふりがな |
| key | string | URLキー |
| old_key | string | 旧vkdb.jpのキー |
| unit_type | enum | ユニットタイプ |
| status | enum | ステータス |
| old_wiki_text | text | 元のwikiテキスト |

## トラブルシューティング

### 個人ページがスキップされる

`{{category 個人}}`が含まれているか確認してください。

### リンクがインポートされない

- リンク形式が正しいか確認（`[[Service:Account]]`または`[Label|URL]`）
- `{{unlink}}`ブロック内のリンクは`active: false`になります

### 誕生日が1904年になる

仕様です。`birthday`カラムは月日のみを保存し、年は常に1904年（うるう年）に正規化されます。実際の生まれ年は`birth_year`カラムに保存されます。

## 開発

### 新しいリンクサービスの追加

`wikipage_parser.rb`の`LinkParser.parse_links`メソッドに追加：

```ruby
when "newservice"
  url = "https://newservice.com/#{account}"
  text = "New Service"
```

### 新しいカテゴリの追加

`wikipage_parser.rb`の`CategoryParser.parse_categories`メソッドに追加：

```ruby
if content =~ /\{\{category 新カテゴリ\}\}/
  categories[:new_category] = true
end
```
