# frozen_string_literal: true

class UnitSnapshotsComponent < ViewComponent::Base
  # summary_preview: 過去(current: false)スナップショットの初期表示方法。
  # true（デフォルト。ユニットページ本体での表示）  → メンバー名の1行プレビュー＋
  #   クリック時にhx-getで遅延取得（読み込みコストを抑えるための本番向け最適化）。
  # false（{{snapshot}}プラグイン。カスタムページでの埋め込み表示）             → 1行プレビューを
  #   出さず、「現メンバー」表示と同じくメンバー一覧をその場で常時表示する
  #   （{{div_begin class="members"}}と同じ見た目。開閉トグルはメンバーごとの経歴
  #   表示のみを対象にする）。1件のsnapshotのみを表示する用途のためデータ量が
  #   小さく、遅延取得のコストは不要。
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
