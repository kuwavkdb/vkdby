# Wikipage Import Scripts

このディレクトリには、Wikipageデータをインポートするためのスクリプトが含まれています。

## クイックスタート (全データ再構築)

データを初期化して全て再インポートする場合のコマンド例です:

旧データをそのままインポート
```bash
import_wikipages_form_mysql.sh
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:old_trends
sh script/import_release_schedule_from_mysql.sh
```

vkdbyデータをクリアしてから旧データをコンバート
```bash
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:truncate_units_and_people
#PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:reset
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units_v2
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:people
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails convert:truncate_trends_and_items
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails convert:old_trends
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails convert:items
```

## スクリプト一覧

### 1. import:people - 個人データ一括インポート

Wikipageから個人（Person）データを一括でインポートします。
`app/services/person_importer.rb` を使用して処理されます。

**使用方法**:
```bash
# 全件インポート
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:people

# パラメータ指定
ID=15962 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:people     # 特定IDのみ
START=10000 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:people  # ID 10000以降
LIMIT=10 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:people     # 最大10件まで
```

**インポート対象**:
- 名前・ふりがな（titleから）
- 誕生日・誕生年（categoryタグから）
- 血液型・出身地（categoryタグから）
- パート（categoryタグから）
- ステータス（引退、フリー、死去など）
- SNSリンク（`[[Twitter:account]]`など）
- 経歴（`!!経歴`セクション）
- カテゴリ（TagIndex）

**条件**:
- `{{category 個人}}`が含まれるページのみインポート
- それ以外はスキップされます

**ステータス判定**（優先順位順）:
1. `{{category 死去}}` → `status: passed_away`
2. `{{category 個人/状況不明}}` → `status: unknown`
3. `{{category 引退}}` → `status: retirement`
4. `{{category 個人/フリー}}` → `status: free`
5. それ以外 → `status: active`

**Key生成**:
- ふりがな + 誕生日（MMDD形式）
- 例: `tomoya-1028`（トモヤ、10月28日生まれ）

### 2. import:units - ユニットデータ一括インポート

Wikipageからユニット（Unit）データを一括でインポートします。
`app/services/wikipage_importer.rb` を使用して処理されます。

**使用方法**:
```bash
# 全件インポート
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units

# パラメータ指定
ID=6555 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units       # 特定IDのみ
START=5000 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units    # ID 5000以降
LIMIT=10 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units      # 最大10件まで
```

### 2-2. import:units_v2 - ユニットデータ + スナップショット一括インポート (V2)

Wikipageからユニット（Unit）データと、日付付きメンバーセクションからスナップショット（UnitSnapshot）データを一括でインポートします。
`app/services/wikipage_importer_v2.rb` を使用して処理されます。

**使用方法**:
```bash
# 全件インポート
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units_v2

# パラメータ指定
ID=6555 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units_v2       # 特定IDのみ
START=5000 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units_v2    # ID 5000以降
LIMIT=10 PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:units_v2      # 最大10件まで
```

**インポート対象**:
- `import:units` と同じユニットデータ
- 日付付きメンバーセクションから `unit_snapshots` + `snapshot_people` レコード

**対応する日付形式**:
- `!!メンバー（yyyy/mm/dd）` - 例: `!!メンバー（2023/04/15）`
- `!!メンバー（yyyy年mm月dd日）` - 例: `!!メンバー（2023年4月15日）`
- `!!メンバー（ラベル）` - 例: `!!メンバー（結成時）` ※日付なしのため、スナップショットは作成されません

**注意**:
- 既存のスナップショットがある場合はスキップされます
- 日付がない（ラベルのみの）セクションはスキップされます


### 3. import:reset - インポートデータの初期化

インポートされたデータを全て削除し、データベースを初期状態（インポート前）に戻します。
`UnitPerson`, `PersonLog`, `UnitLog`, `TagIndexItem`, `Link`, `Person`, `Unit`, `TagIndex` (一部) が削除されます。

**使用方法**:
```bash
PATH=/opt/homebrew/opt/ruby/bin:$PATH bin/rails import:reset
```
**注意**: 実行するとデータは復元できません。開発環境でのテストデータのリセット等に使用してください。

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

## トレンドデータの移行

### 4. import:old_trends - 旧トレンドデータのインポート
MySQLのダンプファイル (`trends_all_YYYYMMDD.sql`) から、中間テーブル `old_trends` へデータをインポートします。

```bash
# プロジェクトルートにSQLファイルを配置した状態で実行
bin/rails import:old_trends
```

### 5. convert:old_trends - 新トレンドテーブルへのコンバート
`old_trends` テーブルのデータを解析・変換し、正規の `trends` テーブルへ移行します。
この処理では以下が行われます：
- `wikipage_id` を元にした `Unit` / `Person` との関連付け
- `content` の解析による `phenomenon` (現象タイプ) の判定
- 日付文字列のパースと補正 (`day_unknown`, `month_unknown` フラグの設定)
- `content` の1行目を `title` として抽出

```bash
bin/rails convert:old_trends
```

**注意**: このタスクを実行すると、既存の `trends` テーブルのデータは全て削除 (`delete_all`) された上で再作成されます。

## アイテムデータの移行

### 6. import_release_schedule_from_mysql.sh - Amazon商品元データのインポート
MySQLのダンプファイル (`release_schedule_all_YYYYMMDD.sql`) から、中間テーブル `release_schedules` へデータをインポートします。

```bash
sh script/import_release_schedule_from_mysql.sh
```

**仕様**:
- プロジェクトルートにある最新の `release_schedule_all_*.sql` を自動的に読み込みます。
- MySQL形式のダンプをPostgreSQL形式に変換しつつインポートします。
- 実行時に既存の `release_schedules` データは削除されます。

### 7. convert:items - Itemテーブルへのコンバート
`release_schedules` テーブルのデータを解析・変換し、正規の `items` テーブルへ移行します。
`app/services/item_converter.rb` を使用して、アーティストの紐付け（`old_key` 形式への変換）などが行われます。

```bash
# 全件コンバート (既存の items は削除されます)
bin/rails convert:items

# パラメータ指定
LIMIT=100 bin/rails convert:items  # 件数制限
ID=1234  bin/rails convert:items   # 特定IDのみ
```

**注意**: このタスクを実行すると、既存の `items` テーブルのデータは全て削除 (`delete_all`) された上で再作成されます。

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

（略）

## 開発

### 新しいリンクサービスの追加

`app/services/person_importer.rb` および `app/services/wikipage_importer.rb` の `map_service_link` メソッドに追加してください。

### 新しいカテゴリの追加

各Importerサービスの `parse_categories` メソッドに追加してください。
