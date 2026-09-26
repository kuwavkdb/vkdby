# 既存 Trend への会場の後付け（バックフィル）

既存の Trend のタイトル・本文に書かれた会場名を Venue と突き合わせ、`trends.venue_id` を後から設定する手順と仕様です（issue #1690）。

## 概要

- rake タスク `trends:backfill_venues` から実行します。突き合わせは `TrendVenueMatcher`（`app/services/trend_venue_matcher.rb`）が行います
- **タイトル・本文は変更しません**。書き換えるのは `venue_id` のみです
- `venue_id` が既に入っている Trend は手動で設定済みとみなし、対象外にします（上書きしません）
- `update_column` で更新するため、バリデーション・コールバックは実行されず、`updated_at` も変わりません（トップページの「最近の更新」に一斉に浮上しないようにするため）

## 前提

先に Venue が登録されている必要があります。本番DBには `wikipages` がないため、本番では `import:venues` は使えません。ローカルで取り込んだ Venue を `script/transfer_venues_to_render.sh` で本番に移してから、このタスクを実行してください（手順は [venue_import_spec.md の「本番への反映」](venue_import_spec.md#本番への反映)）。

## rake タスクの使い方

既定は dry-run で、DB への書き込みは行いません。`APPLY=1` を付けたときだけ `venue_id` を設定します。

```bash
# dry-run: 件数・一致率・要確認の一覧を表示し、全件の判定結果をTSVに出力する
bundle exec rails trends:backfill_venues

# 本実行: 自動紐付けの対象に venue_id を設定する
APPLY=1 bundle exec rails trends:backfill_venues

# TSVの出力先を指定する（既定: tmp/trend_venue_backfill_YYYYMMDD_HHMMSS.tsv）
OUTPUT=/path/to/result.tsv bundle exec rails trends:backfill_venues
```

**進め方の推奨**: まず dry-run で件数と TSV を確認し、問題なければ `APPLY=1` で本実行する。本実行後に dry-run をもう一度実行すると、残った「手作業で確認」の対象だけが出力される（再実行しても、設定済みの Trend は対象外のため重複して処理されない）。

## 会場名の探し方

次の順に探し、最初に会場が見つかった段階で判定します。

| 順 | 探す場所 | 例 | 見つかった場合 |
| --- | --- | --- | --- |
| 1 | タイトル末尾の半角括弧 | `解散([[池袋CYBER]])`、`活動休止(大塚REDZONE)` | 候補 1 件なら自動紐付け |
| 2 | タイトル中の半角括弧（末尾以外） | `活動終了([[高田馬場AREA]]) → [[ViViD]]` | 候補 1 件なら自動紐付け |
| 3 | 括弧の外・本文の `[[会場名]]` | `**正式加入後の初ライブは11/08([[池袋BlackHole]])` | **自動紐付けしない**（要確認） |

- 3 は「加入後の初ライブ」「ラストライブ」のように、その Trend とは別の公演の会場であることが多いため、自動では紐付けません
- `[[表示|リンク先]]` は表示・リンク先のどちらでも突き合わせます
- 本文の Wiki リンクには人名・ユニット名も含まれるため、会場に一致した名前だけを拾います

## 突き合わせ

- Venue の `name` / `aliases` の名前 / `name_log` の名前 / 旧 Wiki ページ名（`old_key` を EUC-JP として戻したもの）と**完全一致**するものを候補にします（大文字小文字・全角半角・空白の違いは吸収しません）
- 論理削除した Venue は対象外です

## 判定結果

| status | 意味 | 扱い |
| --- | --- | --- |
| `matched` | 候補が 1 件 | `APPLY=1` で `venue_id` を設定 |
| `ambiguous` | 候補が複数（同名の会場が重複登録されている、括弧に複数の会場が書かれている など） | 手作業で確認 |
| `review` | 括弧の外・本文にのみ会場リンクがある | 手作業で確認 |
| `unmatched` | タイトル末尾に括弧はあるが一致する会場がない | 手作業で確認（会場の追加や別名の登録を検討） |
| `none` | 会場名が見つからない | 対象外（TSV にも出力しない） |

## 出力

### 標準出力

- 件数（自動紐付け・候補複数・要確認・一致なし・会場名なし）と一致率
- 候補が複数の名前と、その候補の会場
- 現在の会場名と異なる名前で書かれていたもの（例: `Shibuya O-West → TSUTAYA O-WEST`）
- 一致しなかった名前（件数の多い順に上位 50 件）

### TSV

`none` 以外の全件を 1 行ずつ出力します。

| 列 | 内容 |
| --- | --- |
| `trend_id` / `date` / `title` | 対象の Trend |
| `status` | 上記の判定結果 |
| `source` | 会場名を取った場所（`title_trailing` / `title_parenthetical` / `content`） |
| `names` | 取り出した名前（複数あれば ` / ` 区切り） |
| `venue_ids` / `venue_names` | 候補の会場 |

## 実行後の作業

- **会場の表示名**: Trend の会場表示名は `venue.name_at(Trendの日付)` で `name_log` から引きます。取り込んだ Venue の `name_log` には日付が入っていないため、改名前の名前で書かれた Trend にも現在の名前が表示されます。標準出力の「現在の会場名と異なる名前で書かれていたもの」を参考に、改名した会場は管理画面で `name_log` に使用開始日を入れてください（Trend 側の `venue_name` は変更しません）
- **候補が複数**: 同じ会場が重複登録されている場合（例: `HOLIDAY OSAKA` と、旧名に `HOLIDAY OSAKA` を持つ `Ash OSAKA`）は、管理画面で会場を整理してから再度 dry-run → 本実行すると自動紐付けの対象になります
- **一致なし・要確認**: TSV を見て、管理画面の Trend 編集画面で会場を設定するか、会場の追加・別名の登録を行ってから再実行します
