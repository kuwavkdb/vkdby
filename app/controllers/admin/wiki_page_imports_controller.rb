# frozen_string_literal: true

module Admin
  class WikiPageImportsController < Admin::BaseController
    def index
      @pagy, @wiki_page_imports = pagy(
        WikiPageImport.skipped.includes(:wikipage).order(updated_at: :desc),
        limit: 50
      )
    end
  end
end
