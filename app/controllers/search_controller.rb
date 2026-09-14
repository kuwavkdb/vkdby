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
      # 紐づくSection（discard済み・非公開を除く）の名前もマッチ対象にする。
      # sections テーブルは (sectionable_type, sectionable_id) の複合indexを持つため、
      # このEXISTS句は新規indexなしでも低コストに評価できる。
      @units = Unit.kept.where(<<~SQL.squish, q: search_pattern, section_type: 'Unit')
        name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q
        OR EXISTS (
          SELECT 1 FROM sections
          WHERE sections.sectionable_type = :section_type
            AND sections.sectionable_id = units.id
            AND sections.discarded_at IS NULL
            AND sections.active = TRUE
            AND sections.name ILIKE :q
        )
      SQL
                   .order(relevance_order, updated_at: :desc)
                   .limit(15)
      @people = Person.kept.where(<<~SQL.squish, q: search_pattern, section_type: 'Person')
        name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q OR old_history ILIKE :q
        OR EXISTS (
          SELECT 1 FROM sections
          WHERE sections.sectionable_type = :section_type
            AND sections.sectionable_id = people.id
            AND sections.discarded_at IS NULL
            AND sections.active = TRUE
            AND sections.name ILIKE :q
        )
      SQL
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
