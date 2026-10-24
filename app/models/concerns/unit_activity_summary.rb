# frozen_string_literal: true

# ユニットの結成日・解散日と、現在の公開メンバー。
# 構造化データ（JsonLdHelper#unit_json_ld）とmeta description（MetaDescriptionHelper）で
# 同じ結果を使うためのもの（issue #1937）
module UnitActivitySummary
  extend ActiveSupport::Concern

  # 活動期間などの日付（"2010/01/**" のように、不明な部分を ** で書く）
  # 後ろに文章が続く値（"2013以降状況不明" など）は確定した日付ではないので読まない
  PARTIAL_DATE_PATTERN = %r{\A(\d{4})(?:[/.-](\d{1,2}|\*\*))?(?:[/.-](\d{1,2}|\*\*))?\z}

  class_methods do
    # 読み取れた日付だけを返す。"2010" < "2010-01" < "2010-01-05" と文字列の比較で前後が決まるので、
    # min・max で最も古い・新しい日付を選べる（活動期間は日付順に並んでいるとは限らない）
    def partial_dates(values)
      values.filter_map { |value| partial_date(value) }
    end

    # "2010/01/**" → "2010-01"、"2003/**/**" → "2003"、"2010/1/5" → "2010-01-05"。読めなければ nil
    def partial_date(value)
      match = PARTIAL_DATE_PATTERN.match(value.to_s.strip)
      return unless match

      year = match[1]
      month, day = match.captures.drop(1).map { |part| part == '**' ? nil : part&.to_i }
      return year unless month&.between?(1, 12)
      return "#{year}-#{month.to_s.rjust(2, '0')}" unless day && Date.valid_date?(year.to_i, month, day)

      "#{year}-#{month.to_s.rjust(2, '0')}-#{day.to_s.rjust(2, '0')}"
    end
  end

  # 最も古い活動開始日（"2010-01" のように、分かっている部分だけの文字列）。
  # 始まりの日付が空・日付として読めない（"1999頃" など）活動期間が1つでもあるときは、
  # それより前に結成していた可能性があり確かでないため nil にする（issue #1937）
  def founding_date
    return if activity_periods.any? { |period| self.class.partial_date(period.from).nil? }

    self.class.partial_dates(activity_periods.map(&:from)).min
  end

  # 解散したユニットの、最も新しい活動終了日。
  # 終わりの日付が空・日付として読めない（"2019頃"・"状況不明"・"活動中" など）活動期間が1つでもあるときは、
  # 解散したのかどうか・いつ解散したのかが確かでないため nil にする（前の解散日を最後の解散日と
  # 取り違えないため。issue #1937）
  def dissolution_date
    return unless disbanded?
    return if activity_periods.any? { |period| self.class.partial_date(period.to).nil? }

    self.class.partial_dates(activity_periods.map(&:to)).max
  end

  # 活動休止中か。enum の述語メソッド（freeze?）は Object#freeze と紛らわしいため使わない
  def hiatus?
    status == 'freeze'
  end

  # 現在のスナップショットの在籍メンバー（サポート・非公開の個人を除く）を並び順で返す。
  # snapshots には表示用に読み込み済みのスナップショット（snapshot_people を含む）を渡す
  def current_public_members(snapshots)
    snapshot = snapshots.find { |s| s.current? && !s.past? }
    return [] unless snapshot

    members = snapshot.snapshot_people.select { |sp| sp.active? && !sp.support? }.sort_by(&:sort_order)
    person_ids = members.filter_map(&:person_id)
    return members if person_ids.empty?

    published_ids = Person.published.where(id: person_ids).pluck(:id)
    members.reject { |member| member.person_id && published_ids.exclude?(member.person_id) }
  end
end
