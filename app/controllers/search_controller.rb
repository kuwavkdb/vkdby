# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      normalized_query = normalize_search_query(@query)
      search_pattern = like_pattern(normalized_query)
      exact_pattern = ActiveRecord::Base.sanitize_sql_like(normalized_query)
      relevance_order = Arel.sql(
        "CASE WHEN name ILIKE #{Unit.connection.quote(exact_pattern)} THEN 0 " \
        "WHEN name ILIKE #{Unit.connection.quote("#{exact_pattern}%")} THEN 1 " \
        "WHEN name_kana ILIKE #{Unit.connection.quote(exact_pattern)} THEN 0 " \
        "WHEN name_kana ILIKE #{Unit.connection.quote("#{exact_pattern}%")} THEN 1 " \
        'ELSE 2 END'
      )
      # 検索条件は「View all →」の行き先（/units?q=・/people?q=）と共通（issue #1841）。
      @units = Unit.publicly_visible.matching_keyword(search_pattern)
                   .order(relevance_order, updated_at: :desc)
                   .limit(15)
      @people = Person.kept.matching_keyword(search_pattern)
                      .order(relevance_order, updated_at: :desc)
                      .limit(15)
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
      @custom_pages = []
    end
  end
end
