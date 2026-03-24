# frozen_string_literal: true

module Admin
  class WikiPageImportsController < Admin::BaseController
    before_action :require_admin

    def index
      @include_ignored = params[:include_ignored] == '1'
      scope = WikiPageImport.skipped.includes(:wikipage).order(updated_at: :desc)
      scope = scope.where.not(note: 'ignored') unless @include_ignored
      @pagy, @wiki_page_imports = pagy(scope, limit: 50)
    end

    def bulk_ignore
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      if ids.any?
        WikiPageImport.where(id: ids).update_all(note: 'ignored', updated_at: Time.current)
        redirect_to admin_wiki_page_imports_path, notice: "#{ids.size} 件を ignored にしました"
      else
        redirect_to admin_wiki_page_imports_path, alert: '項目が選択されていません'
      end
    end
  end
end
