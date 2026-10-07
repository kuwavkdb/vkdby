# リダイレクト仕様

旧URLから新URLへのリダイレクト処理の仕様をまとめたドキュメント。

## リダイレクト一覧

| 旧URLパターン | 新URLパターン | ステータス | 担当 |
|---|---|---|---|
| `/{old_key}.html` | `/{key}` | 301 | `LegacyRedirectsController#show` |
| `/{old_key}.html`（会場） | `/venues/{key}` | 301 | `LegacyRedirectsController#show` |
| `/NEWS_{id}` | `/trends/{id}` | 301 | `LegacyRedirectsController#news_redirect` |
| `/ITEM_{asin}` | `/items/{id}` | 301 | `LegacyRedirectsController#item_redirect` |
| `/{unit_key}` (destination_key あり) | `/{destination_key}` | 301 | `ProfilesController#show` |
| `/{person_key}` (destination_key あり) | `/{destination_key}` | 301 | `ProfilesController#show` |
| `/{prev_key}`（スタブレコード経由） | `/{key}`（現在のキー） | 301 | `ProfilesController#show` |
| `/venues/{key}`（destination_key あり・スタブレコード経由） | `/venues/{転送先のkey}` | 301 | `VenuesController#show` |

---

## 各リダイレクトの詳細

### 1. `.html` 拡張子つきURL → プロフィールページ・会場ページ

**旧URL形式:** `/{old_key}.html`  
**新URL形式:** `/{key}`（会場は `/venues/{key}`）

旧システムで使われていた `.html` 拡張子付きURLを、現行プロフィールページ・会場ページへ転送する。

**検索順序（CustomPage → Unit → Person → Venue の順で探す）:**

1. `CustomPage.old_key`（`published` スコープのみ）が一致
2. `CustomPage.old_key` がURLエンコード済み old_key と一致
3. `Unit.old_key` が一致
4. `Unit.old_key` がURLエンコード済み old_key と一致
5. `Unit.aliases` 配列内の `old_key` フィールドが一致
6. `Unit.aliases` 配列内の `old_key` フィールドがURLエンコード済み old_key と一致
7. 上記4〜6パターンを Person でも同様に確認
   - Unit / Person は論理削除済みのものを対象外とする（転送先のプロフィールが 404 になるため）。ただしキー変更・統合の転送元（`destination_key` あり）は対象に含め、プロフィール側の転送に任せる
8. `Venue.old_key` または `Venue.aliases` 配列内の `old_key` が一致（それぞれURLエンコード済み old_key も確認。[issue #1691](https://github.com/kuwavkdb/vkdby/issues/1691)）。旧サイトの Trend 本文の `[[会場名]]` リンクを会場ページへ転送するため。論理削除済みの会場でも `destination_key`（統合・キー変更）を辿った先が公開中なら転送先の会場ページへ転送し、辿れない場合は対象外

CustomPage は `Unit`/`Person` と異なり `aliases` を持たない（[issue #1085](https://github.com/kuwavkdb/vkdby/issues/1085)、初回実装のため単一の `old_key` のみ。複数の旧名を持つページが出てきたら `aliases` の追加を検討）。

**見つからない場合:** 404ページを表示（EUC-JP デコードを試みてユニット名を表示）

**Canonicalヘッダー:** リダイレクト時に `Link: <新URL>; rel="canonical"` レスポンスヘッダーを付与

**関連ファイル:**
- [config/routes.rb:168](../config/routes.rb) — ルート定義
- [app/controllers/legacy_redirects_controller.rb:4](../app/controllers/legacy_redirects_controller.rb) — 処理実装

---

### 2. `/NEWS_{id}` → トレンドページ

**旧URL形式:** `/NEWS_{id}`（id は数字）  
**新URL形式:** `/trends/{id}`

旧システムのニュースURL（NEWS_123 形式）を現行のトレンドページへ転送する。Trend の ID はそのまま引き継ぐ。

**見つからない場合:** 404ページを表示

**関連ファイル:**
- [config/routes.rb:171](../config/routes.rb) — ルート定義
- [app/controllers/legacy_redirects_controller.rb:42](../app/controllers/legacy_redirects_controller.rb) — 処理実装

---

### 3. `/ITEM_{asin}` → アイテムページ

**旧URL形式:** `/ITEM_{asin}`（asin は英大文字・数字）  
**新URL形式:** `/items/{id}`

旧システムのアイテムURL（ITEM_B001234567 形式）を現行のアイテムページへ転送する。ASIN コードで Item を検索し、Item の ID で新URLを生成する。

**見つからない場合:** 404ページを表示

**関連ファイル:**
- [config/routes.rb:174](../config/routes.rb) — ルート定義
- [app/controllers/legacy_redirects_controller.rb:51](../app/controllers/legacy_redirects_controller.rb) — 処理実装

---

### 4. `destination_key` によるプロフィール転送（Unit / Person 共通）

**旧URL形式:** `/{key}`  
**新URL形式:** `/{destination_key}`

Unit または Person のマージ・統合時に使用。`destination_key` が設定されている場合、統合先のプロフィールページへ転送する。Unit・Person どちらにも対応。

**条件:** `destination_key` が存在する場合のみ発動（Unit・Person 共通の処理）

**関連ファイル:**
- [app/controllers/profiles_controller.rb:8](../app/controllers/profiles_controller.rb) — 処理実装
- `units.destination_key` カラム（migration: `20260328031736_add_destination_key_to_units.rb`）
- `people.destination_key` カラム（migration: `20260704033215_add_destination_key_to_people.rb`）

---

### 5. キー変更後のスタブレコード経由リダイレクト（Unit / Person 共通）

**旧URL形式:** `/{prev_key}`（変更前のキー）  
**新URL形式:** `/{key}`（変更後の現在のキー）

管理画面でのキー変更機能（issue #57）に対応する処理。管理者が Unit / Person の `key` を変更すると、`key: prev_key` / `destination_key: 変更後のkey` を持つ discard 済みのスタブレコードが自動生成される。上記4番の `destination_key` 機構と同じコードパスで処理されるため、`ProfilesController#show` 側の実装変更は不要。

**条件:** discard 済みのスタブレコードが該当 `key` で見つかり、かつ `destination_key` が設定されている場合に発動

**複数回リネームされた場合の挙動:** A→B→C とリネームすると、`/A` へのアクセスは `/B` を経由して `/C` まで2ホップでリダイレクトされる（スタブレコードは常に「直前のキー→リネーム時点の新キー」のみを記録するため）

**関連ファイル:**
- [app/controllers/profiles_controller.rb:8](../app/controllers/profiles_controller.rb) — 処理実装（4番と共通）
- 設計・実装詳細: [docs/admin/key_change.md](admin/key_change.md)

---

### 6. 会場ページの転送（`destination_key`）

**旧URL形式:** `/venues/{key}`  
**新URL形式:** `/venues/{転送先のkey}`

会場（Venue）のキー変更・統合で残したスタブレコード（論理削除済み・`destination_key` あり）を経由したアクセスを、転送先の会場ページへ転送する（[issue #1691](https://github.com/kuwavkdb/vkdby/issues/1691)）。Unit / Person と異なり、`Venue.resolve_by_key` で転送を最後まで辿ってから 1 回の 301 で転送する（循環防止のため最大 10 ホップ）。辿った先がない・論理削除済みの場合は 404。

**関連ファイル:**
- [app/controllers/venues_controller.rb](../app/controllers/venues_controller.rb) — 処理実装
- [app/models/venue.rb](../app/models/venue.rb) — `Venue.resolve_by_key`

---

## EUC-JP URLのデコード処理

旧システムのURLが EUC-JP エンコードされている場合に対応するためのミドルウェアが存在する。

**ミドルウェア:** `Middleware::EucJpUrlFixer`  
**挿入位置:** Rackミドルウェアスタックの先頭（`ActionableExceptions` より前）

**処理内容:**

1. **無効な UTF-8 バイト列:** `PATH_INFO` に無効な UTF-8 が含まれる場合、高ビットバイトを `%25HH` 形式に変換
2. **EUC-JP エンコード済みURL:** `%80`〜`%FF` のパターンを `%25HH` に二重エンコードし、Rails のデコード後も `%HH` 文字列として保持

**対象:** GET・HEAD リクエストのみ。`/admin` ルートはスキップ。

**関連ファイル:**
- [lib/middleware/euc_jp_url_fixer.rb](../lib/middleware/euc_jp_url_fixer.rb)
- [config/application.rb:26](../config/application.rb)
