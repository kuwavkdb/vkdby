# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      normalized_query = normalize_search_query(@query)
      # pg_trgmベースのあいまい検索（Unit/Person/CustomPage#text_search）。
      # 紐づくSection名（discard済み・非公開を除く）も検索対象になる（issue #1536）。
      @units = Unit.kept.text_search(normalized_query).limit(15)
      @people = Person.kept.text_search(normalized_query).limit(15)
      @custom_pages = CustomPage.published.non_system_pages.text_search(normalized_query).limit(15)
    else
      @units = []
      @people = []
      @custom_pages = []
    end
  end
end
