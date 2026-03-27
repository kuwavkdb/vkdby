# frozen_string_literal: true

module Admin
  class WikiPageImportsController < Admin::BaseController
    before_action :require_admin

    def index
      @show_manually_set = params[:manually_set] == '1'
      @show_deferred     = params[:show_deferred] == '1'
      @show_ignored      = params[:show_ignored] == '1'
      @ms_page_type      = @show_manually_set ? (params[:ms_page_type].presence || 'unit') : nil
      @q                 = params[:q].presence

      scope = if @show_manually_set
                WikiPageImport.manually_set.where.not(status: 'imported').where(page_type: @ms_page_type).includes(:wikipage).order(updated_at: :desc)
              elsif @show_deferred
                WikiPageImport.deferred.includes(:wikipage).order(updated_at: :desc)
              elsif @show_ignored
                WikiPageImport.skipped.where(manually_set: false, note: 'ignored').includes(:wikipage).order(updated_at: :desc)
              else
                base = WikiPageImport.skipped.where(manually_set: false).where.not(note: 'ignored')
                base = base.joins(:wikipage).where('wikipages.name LIKE ?', "#{@q}%") if @q
                base.includes(:wikipage).order(updated_at: :desc)
              end

      @pagy, @wiki_page_imports = pagy(scope, limit: 50)
    end

    def bulk_set_deferred
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      if ids.any?
        WikiPageImport.where(id: ids).update_all(status: 'deferred', updated_at: Time.current)
        redirect_to admin_wiki_page_imports_path, notice: "#{ids.size} 件を保留にしました"
      else
        redirect_to admin_wiki_page_imports_path, alert: '項目が選択されていません'
      end
    end

    def bulk_ignore
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      if ids.any?
        WikiPageImport.where(id: ids).update_all(note: 'ignored', updated_at: Time.current)
        redirect_to admin_wiki_page_imports_path, notice: "#{ids.size} 件を除外しました"
      else
        redirect_to admin_wiki_page_imports_path, alert: '項目が選択されていません'
      end
    end

    def set_deferred
      wpi = WikiPageImport.find(params[:id])
      wpi.update!(status: 'deferred', updated_at: Time.current)
      redirect_back_or_to admin_wiki_page_imports_path, notice: '保留にしました'
    end

    def set_ignored
      wpi = WikiPageImport.find(params[:id])
      wpi.update!(note: 'ignored', updated_at: Time.current)
      redirect_back_or_to admin_wiki_page_imports_path, notice: '除外しました'
    end

    def update_page_type
      wpi = WikiPageImport.find(params[:id])
      page_type = params[:page_type].presence
      if page_type.nil?
        wpi.update!(page_type: nil, manually_set: false)
        redirect_back_or_to admin_wiki_page_imports_path, notice: '手動仕訳をキャンセルしました'
      elsif WikiPageImport::PAGE_TYPES.include?(page_type)
        attrs = { page_type: page_type, manually_set: true }
        attrs[:status] = 'skipped' if wpi.status == 'deferred'
        attrs[:note] = nil if wpi.note == 'ignored'
        wpi.update!(attrs)
        redirect_back_or_to admin_wiki_page_imports_path, notice: "page_type を #{WikiPageImport::PAGE_TYPE_LABELS[page_type]} に設定しました"
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
