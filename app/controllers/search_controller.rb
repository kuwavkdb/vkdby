# frozen_string_literal: true

class SearchController < ApplicationController
  PEOPLE_LIMIT = 15

  def index
    @query = params[:q]

    if @query.present?
      normalized_query = normalize_search_query(@query)
      search_pattern = like_pattern(normalized_query)
      order = relevance_order(normalized_query)
      # 対象（for_index）と検索条件は「View all →」の行き先（/units?q=・/people?q=）と共通（issue #1841）。
      @units = Unit.for_index.matching_keyword(normalized_query)
                   .order(order, updated_at: :desc)
                   .limit(15)
      @people = Person.for_index.matching_keyword(normalized_query)
                      .order(order, updated_at: :desc)
                      .limit(PEOPLE_LIMIT).load
      # 個人ページのないメンバーも個人と同じ欄に、個人ページのある人の後ろに並べる。合計で PEOPLE_LIMIT 件まで（issue #1843）
      remaining = PEOPLE_LIMIT - @people.size
      @unlinked_members = if remaining.positive?
                            SnapshotPerson.unlinked_matching(normalized_query)
                                          .includes(unit_snapshot: :unit)
                                          .limit(remaining).load
                          else
                            []
                          end
      @custom_pages = CustomPage.published.non_system_pages
                                .where(<<~SQL.squish, q: search_pattern, section_type: 'CustomPage')
                                  title ILIKE :q OR body ILIKE :q
                                  OR EXISTS (
                                    SELECT 1 FROM sections
                                    WHERE sections.sectionable_type = :section_type
                                      AND sections.sectionable_id = custom_pages.id
                                      AND sections.discarded_at IS NULL
                                      AND sections.active = TRUE
                                      AND sections.name ILIKE :q
                                  )
                                SQL
                                .order(updated_at: :desc)
                                .limit(15)
    else
      @units = []
      @people = []
      @unlinked_members = []
      @custom_pages = []
    end
  end

  private

  # Unit / Person 共通の並び順（issue #1842）。
  # 0: 現在の名前・ヨミガナと完全一致 1: 名前の履歴・別名も含めたいずれかの名前と（表記ゆれを吸収して）完全一致
  # 2: 現在の名前・ヨミガナと前方一致 3: いずれかの名前と前方一致 4: それ以外
  # search_text は正規化した名前を空白でつないだものなので、前後に空白を足して名前単位で比べる。
  def relevance_order(query)
    conn = ActiveRecord::Base.connection
    exact = ActiveRecord::Base.sanitize_sql_like(query)
    normalized = ActiveRecord::Base.sanitize_sql_like(SearchNormalizer.normalize(query))
    branches = ["WHEN name ILIKE #{conn.quote(exact)} OR name_kana ILIKE #{conn.quote(exact)} THEN 0"]
    branches << "WHEN (' ' || search_text || ' ') LIKE #{conn.quote("% #{normalized} %")} THEN 1" if normalized.present?
    branches << "WHEN name ILIKE #{conn.quote("#{exact}%")} OR name_kana ILIKE #{conn.quote("#{exact}%")} THEN 2"
    branches << "WHEN (' ' || search_text) LIKE #{conn.quote("% #{normalized}%")} THEN 3" if normalized.present?
    Arel.sql("CASE #{branches.join(' ')} ELSE 4 END")
  end
end
