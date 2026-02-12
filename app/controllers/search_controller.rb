# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      search_pattern = "%#{@query}%"
      @units = Unit.where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q', q: search_pattern)
                   .order(updated_at: :desc)
                   .limit(10)
      @people = Person.where('name ILIKE :q OR name_kana ILIKE :q OR name_log::text ILIKE :q', q: search_pattern)
                      .order(updated_at: :desc)
                      .limit(10)
    else
      @units = []
      @people = []
    end
  end
end
