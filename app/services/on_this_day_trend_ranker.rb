# frozen_string_literal: true

# 「今日はなんの日？」の投稿文（OnThisDayPostBuilder、issue #1742）に載せる動向の候補を、優先順位の高い順に並べる。
#   1. メジャー経験バンドの解散・活動休止
#   2. それ以外のバンドの解散・活動休止
#   3. メジャー経験バンドのその他の動向
#   4. それ以外の動向
# 同じ優先度の中はランダム。メジャー経験バンドの判定は年表と同じ Trend.major_debut_unit_ids
class OnThisDayTrendRanker
  PRIORITY_UNIT_PHENOMENA = %w[finish suspend].freeze

  def self.unit_ids(trend)
    (trend.units || []).filter_map { |u| u['unit_id'].presence&.to_i }.to_set
  end

  # 1バンド1件の判定に使うキー。Unitレコードに紐づかない名前だけのユニットは名前で判定する
  def self.unit_keys(trend)
    (trend.units || []).filter_map do |u|
      u['unit_id'].present? ? "id:#{u['unit_id'].to_i}" : u['name'].presence&.then { |name| "name:#{name}" }
    end.to_set
  end

  def initialize(trends, random: Random.new)
    @trends = trends
    @random = random
  end

  def ranked
    @trends.group_by { |trend| priority(trend) }.sort.flat_map { |_, group| group.shuffle(random: @random) }
  end

  private

  def priority(trend)
    major = self.class.unit_ids(trend).intersect?(major_debut_unit_ids)
    if PRIORITY_UNIT_PHENOMENA.include?(trend.unit_phenomenon)
      major ? 1 : 2
    else
      major ? 3 : 4
    end
  end

  def major_debut_unit_ids
    @major_debut_unit_ids ||= Trend.major_debut_unit_ids.to_set
  end
end
