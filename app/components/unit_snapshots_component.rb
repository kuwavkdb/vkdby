# frozen_string_literal: true

class UnitSnapshotsComponent < ViewComponent::Base
  # summary_preview: ユニットページ本体での表示か、{{snapshot}}プラグイン
  # （カスタムページでの埋め込み表示）かを区別するフラグ。
  # true（デフォルト。ユニットページ本体）    → 過去(current: false)スナップショットは
  #   メンバー名の1行プレビュー＋クリック時にhx-getで遅延取得（読み込みコストを
  #   抑えるための本番向け最適化）。current: trueのスナップショットは初期状態から展開。
  # false（{{snapshot}}プラグイン）           → 1行プレビューを出さず、「現メンバー」表示
  #   と同じくメンバー一覧をその場で常時表示する（{{div_begin class="members"}}と同じ
  #   見た目。開閉トグルはメンバーごとの経歴表示のみを対象にする）。1件のsnapshotのみを
  #   表示する用途のためデータ量が小さく、遅延取得のコストは不要。また、current: trueの
  #   スナップショットであっても常に折りたたんだ状態（経歴非表示）から始める
  #   （ユニットページ本体の「現メンバー」自動展開は、プラグイン埋め込みでは行わない）。
  def initialize(snapshots:, unit: nil, admin: false, show_label: true, summary_preview: true)
    super()
    @snapshots = snapshots
    @unit = unit
    @admin = admin
    @show_label = show_label
    @summary_preview = summary_preview
  end

  def render?
    @snapshots.present?
  end
end
