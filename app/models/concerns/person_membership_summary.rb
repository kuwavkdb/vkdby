# frozen_string_literal: true

# 個人の現在・過去の在籍ユニット。
# 構造化データ（JsonLdHelper#person_json_ld）とmeta description（MetaDescriptionHelper）で
# 同じ結果を使うためのもの（issue #1938）
module PersonMembershipSummary
  extend ActiveSupport::Concern

  # 今在籍しているユニット（「現在」のスナップショットの在籍メンバー。サポート・関係者は除く）。
  # 解散したユニットは「現在」のスナップショットが残っていても含めない。
  # 引退した人は、「現在」のスナップショットに在籍として残っていても今の所属は無いものとする
  # （そのユニットは past_units に並ぶ）。死去した人は最後に在籍したユニットをそのまま返す。
  # 「他」で切ったときに載るユニットが表示のたびに入れ替わらないよう、ユニットの id 順にする
  def current_units
    return [] if retirement?

    membership_snapshot_people.where(status: :active)
                              .where(unit_snapshots: { current: true })
                              .where(unit_snapshots: { unit_id: Unit.where.not(status: :disbanded).select(:id) })
                              .order('unit_snapshots.unit_id')
                              .includes(unit_snapshot: :unit)
                              .map { |member| member.unit_snapshot.unit }
                              .uniq
  end

  # 過去に在籍したユニット（在籍・脱退として載っているスナップショットがあるもの。サポート・関係者は除く）。
  # excluding（今の所属。Person#current_units の結果）は除き、載っているスナップショットの日付が新しいユニットから並べる。
  # 日付の無いスナップショットにしか載っていないユニットは最後にし、同じ日付どうしは id 順にする
  # （「他」で切ったときに載るユニットが表示のたびに入れ替わらないようにするため）
  def past_units(excluding:)
    latest_dates = membership_snapshot_people.where(status: %i[active left])
                                             .group('unit_snapshots.unit_id')
                                             .maximum('unit_snapshots.snapshot_date')
    unit_ids = latest_dates.keys - excluding.map(&:id)
    units = Unit.where(id: unit_ids).index_by(&:id)
    unit_ids.sort_by { |unit_id| [latest_dates[unit_id] ? -latest_dates[unit_id].jd : 1, unit_id] }
            .map { |unit_id| units[unit_id] }
  end

  private

  # 所属を求めるもとになる、この個人のスナップショット上の載り方（サポート・関係者スナップショット・
  # 非表示のスナップショットを除く）。非公開のユニットと、キー変更・統合で転送しているユニットも除く
  def membership_snapshot_people
    SnapshotPerson.where(person_id: id, support: false)
                  .joins(:unit_snapshot)
                  .where(unit_snapshots: { past: false, active: true,
                                           unit_id: Unit.for_index.published.where(destination_key: [nil, '']).select(:id) })
  end
end
