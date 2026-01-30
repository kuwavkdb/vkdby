# Wikipage Import Scripts

このディレクトリには、Wikipageデータをインポートするためのスクリプトが含まれています。

## スクリプト一覧

### 1. import:people - 個人データ一括インポート

Wikipageから個人（Person）データを一括でインポートします。
`app/services/person_importer.rb` を使用して処理されます。

**使用方法**:
```bash
# 全件インポート
bin/rails import:people

# パラメータ指定
ID=15962 bin/rails import:people     # 特定IDのみ
START=10000 bin/rails import:people  # ID 10000以降
LIMIT=10 bin/rails import:people     # 最大10件まで
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
bin/rails import:units

# パラメータ指定
ID=6555 bin/rails import:units       # 特定IDのみ
START=5000 bin/rails import:units    # ID 5000以降
LIMIT=10 bin/rails import:units      # 最大10件まで
```

### 3. import:reset - インポートデータの初期化

インポートされたデータを全て削除し、データベースを初期状態（インポート前）に戻します。
`UnitPerson`, `PersonLog`, `UnitLog`, `TagIndexItem`, `Link`, `Person`, `Unit`, `TagIndex` (一部) が削除されます。

**使用方法**:
```bash
bin/rails import:reset
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

