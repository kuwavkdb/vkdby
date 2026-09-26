# frozen_string_literal: true

module Admin
  # ライブハウス・ホールなどの会場の管理（issue #1687）
  class VenuesController < Admin::BaseController # rubocop:disable Metrics/ClassLength
    include LoggableLinkChanges

    before_action :set_venue, only: %i[show edit update destroy undiscard change_key]
    before_action :require_super_operator, only: %i[destroy undiscard]
    before_action :require_admin, only: %i[change_key]

    # new の URL パラメーターで事前入力できる項目（venue-url スキル、issue #1705）
    PREFILL_ATTRIBUTES = %i[name name_kana key venue_type status prefecture area address capacity note].freeze
    PREFILL_NESTED = {
      links: %i[text url],
      aliases: %i[name kana],
      name_logs: %i[name name_kana date]
    }.freeze

    def index
      @q = params[:q]
      @show_discarded = params[:discarded]
      scope = case @show_discarded
              when 'only' then Venue.discarded
              when 'all'  then Venue.with_discarded
              else             Venue.kept
              end
      # キー変更で残した転送用スタブ（論理削除済み・destination_keyあり）だけを表示する
      scope = Venue.with_discarded.where.not(destination_key: nil) if params[:redirect_source] == 'only'
      scope = scope.matching(normalize_search_query(@q)) if @q.present?
      scope = scope.where(venue_type: params[:venue_type]) if Venue.venue_types.key?(params[:venue_type])
      scope = scope.where(prefecture: params[:prefecture]) if Venue::PREFECTURES.include?(params[:prefecture])
      scope = scope.where(status: params[:status]) if Venue.statuses.key?(params[:status])
      @pagy, @venues = pagy(scope.order(updated_at: :desc))
    end

    def show
      redirect_to edit_admin_venue_path(@venue)
    end

    # Trendフォームの会場入力欄のサジェスト用（issue #1689）。転送元のスタブ・論理削除済みは除く
    def search
      q = params[:q].to_s.strip
      venues = if q.present?
                 Venue.kept.where(destination_key: nil).matching(normalize_search_query(q)).order(:name).limit(10)
               else
                 Venue.none
               end

      render json: venues.map { |v|
        { id: v.id, name: v.name, name_kana: v.name_kana, key: v.key,
          location: [v.prefecture, v.area].compact_blank.join(' ').presence }
      }
    end

    # URLパラメーター（venue[...]）での事前入力に対応する（venue-urlスキル、issue #1705）。
    # 事前入力された名前と一致しそうな既存の会場を表示して、重複登録を防ぐ
    def new
      @venue = Venue.new(venue_params_for_new)
      @venue.links.build
      @similar_venues = similar_venues_for(@venue)
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

      if @venue.update(venue_update_params)
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

    def change_key
      new_key = params[:new_key].to_s.strip
      return redirect_to edit_admin_venue_path(@venue), alert: '新しいキーを入力してください。' if new_key.blank?

      @venue.change_key!(new_key)
      record_update_log(@venue, action: 'change_key')
      redirect_to edit_admin_venue_path(@venue), notice: 'キーを変更しました。旧キーは新しいキーへ転送されます。'
    rescue ActiveRecord::RecordNotUnique
      redirect_to edit_admin_venue_path(@venue), alert: 'そのキーはすでに使われています。'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_admin_venue_path(@venue), alert: e.message
    end

    private

    def set_venue
      @venue = Venue.with_discarded.find(params[:id])
    end

    def venue_params
      params.require(:venue).permit(:key, :name, :name_kana, :venue_type, :prefecture, :area, :address,
                                    :capacity, :status, :note, :old_key, :destination_key,
                                    links_attributes: %i[id text url active sort_order _destroy],
                                    name_logs_attributes: %i[name name_kana date],
                                    aliases_attributes: %i[name kana old_key hidden])
    end

    # new（GET）用。params[:venue] が無い初期表示でも動くよう require ではなく緩く読み、
    # enum・都道府県に無い値や正の整数でないキャパシティは無視する（trend-url / unit-url と同じ考え方）。
    # 繰り返し項目は unit-url と同じく短いキー名（venue[links] 等）で受け取り、*_attributes に読み替える
    def venue_params_for_new
      raw = params[:venue]
      return {} unless raw.is_a?(ActionController::Parameters)

      attrs = raw.permit(*PREFILL_ATTRIBUTES).to_h.symbolize_keys
      attrs.delete(:venue_type) unless Venue.venue_types.key?(attrs[:venue_type])
      attrs.delete(:status) unless Venue.statuses.key?(attrs[:status])
      attrs.delete(:prefecture) unless Venue::PREFECTURES.include?(attrs[:prefecture])
      attrs.delete(:capacity) unless attrs[:capacity].to_s.match?(/\A[1-9]\d*\z/)
      PREFILL_NESTED.each do |name, keys|
        rows = nested_prefill_rows(raw[name], keys)
        attrs[:"#{name}_attributes"] = rows if rows.present?
      end
      attrs
    end

    def nested_prefill_rows(value, keys)
      return {} unless value.is_a?(ActionController::Parameters)

      value.to_unsafe_h.each_with_object({}) do |(index, row), rows|
        next unless row.is_a?(Hash)

        rows[index.to_s] = row.slice(*keys.map(&:to_s))
      end
    end

    def similar_venues_for(venue)
      names = [venue.name, *venue.aliases.map(&:name)].compact_blank.uniq
      return Venue.none if names.empty?

      # 論理削除済みも含める（削除済みの会場を作り直してしまわないように）。キー変更の転送用スタブは除く
      names.map { |name| Venue.with_discarded.where(destination_key: nil).matching(name) }.reduce(:or)
           .order(:name).limit(10)
    end

    # key はキー変更専用の操作（change_key）でのみ変更できる。通常の update では受け付けない
    def venue_update_params
      venue_params.except(:key)
    end
  end
end
