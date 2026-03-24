# frozen_string_literal: true

module Admin
  class WikiPageImportsController < Admin::BaseController
    def index
      @include_ignored = params[:include_ignored] == '1'
      scope = WikiPageImport.skipped.includes(:wikipage).order(updated_at: :desc)
      scope = scope.where.not(note: 'ignored') unless @include_ignored
      @pagy, @wiki_page_imports = pagy(scope, limit: 50)
    end
  end
end
