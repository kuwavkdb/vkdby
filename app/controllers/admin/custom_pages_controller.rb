# frozen_string_literal: true

module Admin
  class CustomPagesController < Admin::BaseController
    before_action :set_custom_page, only: %i[edit update destroy undiscard]
    before_action :require_super_operator, only: %i[destroy undiscard]
    before_action :deny_if_protected, only: %i[destroy]

    def index
      @q = params[:q]

      scope = case params[:discarded]
              when 'only' then CustomPage.discarded
              when 'all'  then CustomPage.with_discarded
              else             CustomPage.kept
              end

      scope = scope.where('key ILIKE :q OR title ILIKE :q', q: "%#{@q}%") if @q.present?

      @pagy, @custom_pages = pagy(scope.order(updated_at: :desc), limit: 20)
    end

    def new
      @custom_page = CustomPage.new
    end

    def edit; end

    def create
      @custom_page = CustomPage.new(custom_page_params)

      if @custom_page.save
        redirect_to admin_custom_pages_path, notice: 'ページを作成しました。'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @custom_page.update(custom_page_params)
        redirect_to admin_custom_pages_path, notice: 'ページを更新しました。'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @custom_page.discard
      redirect_to admin_custom_pages_path, notice: 'ページを削除しました。'
    end

    def undiscard
      @custom_page.undiscard
      redirect_to admin_custom_pages_path, notice: 'ページを復元しました。'
    end

    private

    def set_custom_page
      @custom_page = CustomPage.with_discarded.find(params[:id])
    end

    def deny_if_protected
      return unless @custom_page.protected?

      redirect_to admin_custom_pages_path, alert: "「#{@custom_page.key}」は削除できません。"
    end

    def custom_page_params
      params.require(:custom_page).permit(:key, :title, :body, :active)
    end
  end
end
