# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]

    if @query.present?
      normalized_query = normalize_search_query(@query)
      @units = apply_text_search(Unit.kept, normalized_query).limit(15)
      @people = apply_text_search(Person.kept, normalized_query).limit(15)
      @custom_pages = apply_text_search(CustomPage.published.non_system_pages, normalized_query).limit(15)
    else
      @units = []
      @people = []
      @custom_pages = []
    end
  end

  private

  # pg_trgmベースのあいまい検索（Unit/Person/CustomPage#text_search）。紐づくSection名
  # （discard済み・非公開を除く）も検索対象になる。SEARCH_BACKEND=legacy を指定すると、
  # コード変更なしで置き換え前のILIKEベースの検索（#legacy_text_search）に戻せる
  # （issue #1536。問題が起きた場合の当面のロールバック手段）。
  def apply_text_search(relation, normalized_query)
    if Rails.application.config.search_backend == 'legacy'
      relation.legacy_text_search(normalized_query)
    else
      relation.text_search(normalized_query)
    end
  end
end
