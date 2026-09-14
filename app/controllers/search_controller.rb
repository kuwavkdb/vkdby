# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      normalized_query = normalize_search_query(@query)
      search_pattern = "%#{normalized_query}%"
      exact_pattern = ActiveRecord::Base.sanitize_sql_like(normalized_query)
      relevance_order = Arel.sql(
        "CASE WHEN name ILIKE #{Unit.connection.quote(exact_pattern)} THEN 0 " \
        "WHEN name ILIKE #{Unit.connection.quote("#{exact_pattern}%")} THEN 1 " \
        "WHEN name_kana ILIKE #{Unit.connection.quote(exact_pattern)} THEN 0 " \
        "WHEN name_kana ILIKE #{Unit.connection.quote("#{exact_pattern}%")} THEN 1 " \
        'ELSE 2 END'
      )
      units_condition = 'name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q ' \
                         "OR #{section_name_match_sql('Unit', 'units.id')}"
      @units = Unit.kept.where(units_condition, q: search_pattern)
                   .order(relevance_order, updated_at: :desc)
                   .limit(15)
      people_condition = 'name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q OR old_history ILIKE :q ' \
                          "OR #{section_name_match_sql('Person', 'people.id')}"
      @people = Person.kept.where(people_condition, q: search_pattern)
                      .order(relevance_order, updated_at: :desc)
                      .limit(15)
      custom_pages_condition = "title ILIKE :q OR body ILIKE :q OR #{section_name_match_sql('CustomPage', 'custom_pages.id')}"
      @custom_pages = CustomPage.published.non_system_pages
                                .where(custom_pages_condition, q: search_pattern)
                                .order(updated_at: :desc)
                                .limit(15)
    else
      @units = []
      @people = []
      @custom_pages = []
    end
  end

  private

  # 紐づくSection（discard済み・非公開を除く）の名前もマッチ対象にするEXISTS句。
  # sections テーブルは (sectionable_type, sectionable_id) の複合indexを持つため、
  # 呼び出し元のクエリごとにこのindexで絞り込んでからname ILIKE比較する形になり、
  # 新規indexなしでも低コストに評価できる。
  def section_name_match_sql(sectionable_type, id_column)
    quoted_type = ActiveRecord::Base.connection.quote(sectionable_type)
    <<~SQL.squish
      EXISTS (
        SELECT 1 FROM sections
        WHERE sections.sectionable_type = #{quoted_type}
          AND sections.sectionable_id = #{id_column}
          AND sections.discarded_at IS NULL
          AND sections.active = TRUE
          AND sections.name ILIKE :q
      )
    SQL
  end
end
