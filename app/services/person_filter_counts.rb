# frozen_string_literal: true

# /peopleの索引ページのフィルタ選択肢（パート・血液型・出身地・ステータス）ごとの
# 件数を集計する。件数はPersonのparts/blood/hometown/statusが変化した時にしか
# 変わらないため、索引ページアクセスごとに毎回集計せずキャッシュする（既存の
# サイドバーキャッシュ issue #1602 と同様の方針）。PeopleController#index側の
# 失効はPerson#expire_filter_counts_cacheから呼ばれる。
class PersonFilterCounts
  CACHE_KEY = 'people/index_filter_counts'
  CACHE_TTL = 10.minutes
  RACE_CONDITION_TTL = 10.seconds

  def self.call
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL, race_condition_ttl: RACE_CONDITION_TTL) { new.compute }
  end

  def self.expire
    Rails.cache.delete(CACHE_KEY)
  end

  def compute
    hometown_counts = base_scope.where.not(hometown: [nil, '']).group(:hometown).count
                                .sort_by { |h, c| [Person::PREFECTURES.index(h) || Person::PREFECTURES.size, -c] }
    {
      part: Person::AVAILABLE_PARTS.index_with { |p| base_scope.where('parts @> ?::jsonb', [p].to_json).count },
      blood: Person::BLOOD_TYPES.index_with { |b| base_scope.where(blood: b).count },
      hometown: hometown_counts,
      status: Person.statuses.keys.index_with { |s| base_scope.where(status: s).count }
    }
  end

  private

  def base_scope
    Person.for_index
  end
end
