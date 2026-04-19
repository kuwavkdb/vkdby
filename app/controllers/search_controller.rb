# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      search_pattern = "%#{@query}%"
      exact_pattern = ActiveRecord::Base.sanitize_sql_like(@query)
      relevance_order = Arel.sql(
        "CASE WHEN name ILIKE #{Unit.connection.quote(exact_pattern)} THEN 0 " \
        "WHEN name ILIKE #{Unit.connection.quote("#{exact_pattern}%")} THEN 1 " \
        "WHEN name_kana ILIKE #{Unit.connection.quote(exact_pattern)} THEN 0 " \
        "WHEN name_kana ILIKE #{Unit.connection.quote("#{exact_pattern}%")} THEN 1 " \
        'ELSE 2 END'
      )
      @units = Unit.kept.where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q', q: search_pattern)
                   .order(relevance_order, updated_at: :desc)
                   .limit(15)
      people_condition = 'name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q OR old_history ILIKE :q'
      @people = Person.kept.where(people_condition, q: search_pattern)
                      .order(relevance_order, updated_at: :desc)
                      .limit(15)
    else
      @units = []
      @people = []
    end
  end
end
