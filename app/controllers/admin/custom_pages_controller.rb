# frozen_string_literal: true

module Admin
  class CustomPagesController < Admin::BaseController
    before_action :set_custom_page, only: %i[edit update destroy undiscard upload_image]
    before_action :require_admin, only: %i[upload_image]
    before_action :require_super_operator, only: %i[destroy undiscard]
    before_action :deny_if_protected, only: %i[destroy]
    before_action :deny_if_self_blocking, only: %i[create update]

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

    def upload_image
      image = params[:image]
      raise ActionController::BadRequest, 'Invalid file type' unless image&.content_type&.start_with?('image/')

      @custom_page.images.attach(image)
      render json: { url: url_for(@custom_page.images.last) }
    end

    private

    def set_custom_page
      @custom_page = CustomPage.with_discarded.find(params[:id])
    end

    def deny_if_protected
      return unless @custom_page.protected?

      redirect_to admin_custom_pages_path, alert: "「#{@custom_page.key}」は削除できません。"
    end

    def deny_if_self_blocking
      params_key = custom_page_params[:key].presence || @custom_page&.key
      return unless params_key == Middleware::IpBlocker::CUSTOM_PAGE_KEY

      body = custom_page_params[:body].to_s
      ips = body.lines.filter_map do |line|
        line = line.strip
        next if line.empty? || line.match?(/\A~~.+~~\z/)

        line
      end

      return unless ips.include?(request.ip)

      alert_msg = "自分自身のIPアドレス（#{request.ip}）がブロック対象に含まれています。保存するとアクセスできなくなります。取り消し線（~~#{request.ip}~~）を付けるか、行を削除してください。"
      if @custom_page
        redirect_to edit_admin_custom_page_path(@custom_page), alert: alert_msg
      else
        @custom_page = CustomPage.new(custom_page_params)
        flash.now[:alert] = alert_msg
        render :new, status: :unprocessable_entity
      end
    end

    def custom_page_params
      params.require(:custom_page).permit(:key, :title, :body, :active)
    end
  end
end
