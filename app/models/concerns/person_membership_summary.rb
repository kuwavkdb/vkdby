# frozen_string_literal: true

# 個人の現在・過去の在籍ユニット。
# 構造化データ（JsonLdHelper#person_json_ld）とmeta description（MetaDescriptionHelper）で
# 同じ結果を使うためのもの（issue #1938）
module PersonMembershipSummary
  extend ActiveSupport::Concern

  # 今在籍しているユニット（「現在」のスナップショットの在籍メンバー。サポート・関係者は除く）。
  # 解散したユニットは「現在」のスナップショットが残っていても含めない
  def current_units
    SnapshotPerson.where(person_id: id, status: :active, support: false)
                  .joins(:unit_snapshot)
                  .where(unit_snapshots: { current: true, past: false, active: true,
                                           unit_id: membership_listable_units.where.not(status: :disbanded).select(:id) })
                  .includes(unit_snapshot: :unit)
                  .map { |member| member.unit_snapshot.unit }
                  .uniq
  end

  # 過去に在籍したユニット（在籍・脱退として載っているスナップショットがあるもの。サポート・関係者は除く）。
  # excluding（今在籍しているユニット）は除き、載っているスナップショットの日付が新しいユニットから並べる。
  # 日付の無いスナップショットにしか載っていないユニットは最後にする
  def past_units(excluding: current_units)
    latest_dates = SnapshotPerson.where(person_id: id, status: %i[active left], support: false)
                                 .joins(:unit_snapshot)
                                 .where(unit_snapshots: { past: false, active: true,
                                                          unit_id: membership_listable_units.select(:id) })
                                 .group('unit_snapshots.unit_id')
                                 .maximum('unit_snapshots.snapshot_date')
    unit_ids = latest_dates.keys - excluding.map(&:id)
    units = Unit.where(id: unit_ids).index_by(&:id)
    unit_ids.sort_by { |unit_id| latest_dates[unit_id] ? -latest_dates[unit_id].jd : 0 }.map { |unit_id| units[unit_id] }
  end

  private

  # 所属として出してよいユニット。非公開のユニットと、キー変更・統合で転送しているユニットは除く
  def membership_listable_units
    Unit.for_index.published.where(destination_key: [nil, ''])
  end
end
