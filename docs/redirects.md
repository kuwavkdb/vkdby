# リダイレクト仕様

旧URLから新URLへのリダイレクト処理の仕様をまとめたドキュメント。

## リダイレクト一覧

| 旧URLパターン | 新URLパターン | ステータス | 担当 |
|---|---|---|---|
| `/{old_key}.html` | `/profile/{key}` | 301 | `LegacyRedirectsController#show` |
| `/NEWS_{id}` | `/trends/{id}` | 301 | `LegacyRedirectsController#news_redirect` |
| `/ITEM_{asin}` | `/items/{id}` | 301 | `LegacyRedirectsController#item_redirect` |
| `/profile/{unit_key}` (destination_key あり) | `/profile/{destination_key}` | 301 | `ProfilesController#show` |
| `/profile/{person_key}` (destination_key あり) | `/profile/{destination_key}` | 301 | `ProfilesController#show` |

---

## 各リダイレクトの詳細

### 1. `.html` 拡張子つきURL → プロフィールページ

**旧URL形式:** `/{old_key}.html`  
**新URL形式:** `/profile/{key}`

旧システムで使われていた `.html` 拡張子付きURLを、現行プロフィールページへ転送する。

**検索順序（Unit → Person の順で探す）:**

1. `Unit.old_key` が一致
2. `Unit.old_key` がURLエンコード済み old_key と一致
3. `Unit.aliases` 配列内の `old_key` フィールドが一致
4. `Unit.aliases` 配列内の `old_key` フィールドがURLエンコード済み old_key と一致
5. 上記4パターンを Person でも同様に確認

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

**旧URL形式:** `/profile/{key}`  
**新URL形式:** `/profile/{destination_key}`

Unit または Person のマージ・統合時に使用。`destination_key` が設定されている場合、統合先のプロフィールページへ転送する。Unit・Person どちらにも対応。

**条件:** `destination_key` が存在する場合のみ発動（Unit・Person 共通の処理）

**関連ファイル:**
- [app/controllers/profiles_controller.rb:8](../app/controllers/profiles_controller.rb) — 処理実装
- `units.destination_key` カラム（migration: `20260328031736_add_destination_key_to_units.rb`）
- `people.destination_key` カラム（migration: `20260704033215_add_destination_key_to_people.rb`）

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
