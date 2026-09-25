# frozen_string_literal: true

module Admin
  # ライブハウス・ホールなどの会場の管理（issue #1687）
  class VenuesController < Admin::BaseController
    include LoggableLinkChanges

    before_action :set_venue, only: %i[show edit update destroy undiscard]
    before_action :require_super_operator, only: %i[destroy undiscard]

    def index
      @q = params[:q]
      @show_discarded = params[:discarded]
      scope = case @show_discarded
              when 'only' then Venue.discarded
              when 'all'  then Venue.with_discarded
              else             Venue.kept
              end
      if @q.present?
        scope = scope.where(
          'name ILIKE :q OR name_kana ILIKE :q OR key ILIKE :q OR name_log::text ILIKE :q OR aliases::text ILIKE :q',
          q: "%#{Venue.sanitize_sql_like(normalize_search_query(@q))}%"
        )
      end
      scope = scope.where(venue_type: params[:venue_type]) if Venue.venue_types.key?(params[:venue_type])
      scope = scope.where(prefecture: params[:prefecture]) if Venue::PREFECTURES.include?(params[:prefecture])
      scope = scope.where(status: params[:status]) if Venue.statuses.key?(params[:status])
      @pagy, @venues = pagy(scope.order(updated_at: :desc))
    end

    def show
      redirect_to edit_admin_venue_path(@venue)
    end

    def new
      @venue = Venue.new
      @venue.links.build
    end

    def edit
      @venue.links.build
      @wiki_page_imports = @venue.wiki_page_imports.includes(:wikipage).order(updated_at: :desc)
      @update_logs = UpdateLog.for_venue(@venue).includes(:user).order(created_at: :desc).limit(50)
    end

    def create
      @venue = Venue.new(venue_params)

      if @venue.save
        record_update_log(@venue, action: 'create')
        @venue.links.each { |link| record_update_log(link, action: 'create', subject: @venue) }
        redirect_to edit_admin_venue_path(@venue), notice: '会場を作成しました。'
      else
        @venue.links.build if @venue.links.none?(&:new_record?)
        render :new, status: :unprocessable_entity
      end
    end

    def update
      pre_link_ids = @venue.links.pluck(:id)

      if @venue.update(venue_params)
        record_update_log(@venue, action: 'update')
        record_link_changes(@venue, pre_link_ids)
        redirect_to edit_admin_venue_path(@venue), notice: '会場を更新しました。'
      else
        @venue.links.build if @venue.links.none?(&:new_record?)
        @wiki_page_imports = @venue.wiki_page_imports.includes(:wikipage).order(updated_at: :desc)
        @update_logs = UpdateLog.for_venue(@venue).includes(:user).order(created_at: :desc).limit(50)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @venue.discard
      record_update_log(@venue, action: 'discard')
      redirect_to admin_venues_path, notice: '会場を削除しました。'
    end

    def undiscard
      @venue.undiscard
      record_update_log(@venue, action: 'undiscard')
      redirect_to admin_venues_path, notice: '会場を復元しました。'
    end

    private

    def set_venue
      @venue = Venue.with_discarded.find(params[:id])
    end

    def venue_params
      params.require(:venue).permit(:key, :name, :name_kana, :venue_type, :prefecture, :area, :address,
                                    :capacity, :status, :note, :old_key,
                                    links_attributes: %i[id text url active sort_order _destroy],
                                    name_logs_attributes: %i[name name_kana date],
                                    aliases_attributes: %i[name kana old_key hidden])
    end
  end
end
