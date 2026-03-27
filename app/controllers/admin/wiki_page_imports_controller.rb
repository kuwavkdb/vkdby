# frozen_string_literal: true

module Admin
  class WikiPageImportsController < Admin::BaseController
    before_action :require_admin

    def index
      @show_manually_set = params[:manually_set] == '1'
      @show_deferred     = params[:show_deferred] == '1'
      @show_ignored      = params[:show_ignored] == '1'

      if @show_manually_set
        scope = WikiPageImport.manually_set.where.not(status: 'imported').includes(:wikipage).order(updated_at: :desc)
      elsif @show_deferred
        scope = WikiPageImport.deferred.includes(:wikipage).order(updated_at: :desc)
      elsif @show_ignored
        scope = WikiPageImport.skipped.where(manually_set: false, note: 'ignored').includes(:wikipage).order(updated_at: :desc)
      else
        scope = WikiPageImport.skipped.where(manually_set: false).where.not(note: 'ignored').includes(:wikipage).order(updated_at: :desc)
      end

      @pagy, @wiki_page_imports = pagy(scope, limit: 50)
    end

    def bulk_set_deferred
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      if ids.any?
        WikiPageImport.where(id: ids).update_all(status: 'deferred', updated_at: Time.current)
        redirect_to admin_wiki_page_imports_path, notice: "#{ids.size} 件を deferred にしました"
      else
        redirect_to admin_wiki_page_imports_path, alert: '項目が選択されていません'
      end
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

    def update_page_type
      wpi = WikiPageImport.find(params[:id])
      page_type = params[:page_type].presence
      if page_type.nil?
        wpi.update!(page_type: nil, manually_set: false)
        redirect_back_or_to admin_wiki_page_imports_path, notice: '手動仕訳をキャンセルしました'
      elsif WikiPageImport::PAGE_TYPES.include?(page_type)
        wpi.update!(page_type: page_type, manually_set: true)
        redirect_back_or_to admin_wiki_page_imports_path, notice: "page_type を #{page_type} に設定しました"
      else
        redirect_to admin_wiki_page_imports_path, alert: '無効な page_type です'
      end
    end

    def bulk_update_page_type
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      page_type = params[:page_type].presence
      if ids.empty?
        redirect_to admin_wiki_page_imports_path, alert: '項目が選択されていません'
      elsif page_type.nil?
        WikiPageImport.where(id: ids).update_all(page_type: nil, manually_set: false, updated_at: Time.current)
        redirect_back_or_to admin_wiki_page_imports_path, notice: "#{ids.size} 件の手動仕訳をキャンセルしました"
      elsif WikiPageImport::PAGE_TYPES.include?(page_type)
        WikiPageImport.where(id: ids).update_all(page_type: page_type, manually_set: true, updated_at: Time.current)
        redirect_back_or_to admin_wiki_page_imports_path, notice: "#{ids.size} 件の page_type を #{page_type} に設定しました"
      else
        redirect_to admin_wiki_page_imports_path, alert: 'page_type を選択してください'
      end
    end
  end
end
