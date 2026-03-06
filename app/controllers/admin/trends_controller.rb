# frozen_string_literal: true

module Admin
  class TrendsController < Admin::BaseController
    before_action :set_trend, only: %i[edit update destroy]
    before_action :require_super_operator, only: %i[destroy]

    def index
      @q = params[:q]
      scope = Trend.all.order(date: :desc)

      # 日付検索
      if params[:year].present?
        year = params[:year].to_i
        scope = scope.where('EXTRACT(YEAR FROM date) = ?', year)
      end

      # テキスト検索（title, content）
      scope = scope.where('title ILIKE :q OR content ILIKE :q', q: "%#{@q}%") if @q.present?

      @pagy, @trends = pagy(scope, limit: 20)

      # Load related units for display
      all_unit_ids = @trends.flat_map { |t| t.units&.map { |u| u['unit_id'] } }.compact.uniq
      @related_units = Unit.where(id: all_unit_ids).index_by(&:id)
    end

    def new
      @trend = Trend.new(trend_params_for_new)
      @trend.date ||= Date.current
      @trend.publish_start_at ||= Time.current
      @trend.active = true

      if params[:unit_id].present?
        unit = Unit.find_by(id: params[:unit_id])
        if unit
          @trend.units = [{ 'unit_id' => unit.id, 'name' => unit.name }]
          set_snapshots_from_trend
        end
      end

      return unless params[:person_id].present?

      person = Person.find_by(id: params[:person_id])
      @trend.people = [{ 'person_id' => person.id, 'name' => person.name }] if person
    end

    def edit
      @related_units = Unit.where(id: (@trend.units || []).map { |u| u['unit_id'] }).index_by(&:id)
      @related_people = Person.where(id: (@trend.people || []).map { |p| p['person_id'] }).index_by(&:id)
      set_snapshots_from_trend
    end

    def create
      @trend = Trend.new(trend_params)

      if @trend.save
        redirect_to admin_trends_path, notice: 'Trend created successfully.'
      else
        set_snapshots_from_trend
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @trend.update(trend_params)
        redirect_to admin_trends_path, notice: 'Trend updated successfully.'
      else
        @related_units = Unit.where(id: (@trend.units || []).map { |u| u['unit_id'] }).index_by(&:id)
        @related_people = Person.where(id: (@trend.people || []).map { |p| p['person_id'] }).index_by(&:id)
        set_snapshots_from_trend
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @trend.destroy
      redirect_to admin_trends_path, notice: 'Trend deleted successfully.'
    end

    private

    def set_trend
      @trend = Trend.find(params[:id])
    end

    def trend_params
      params.require(:trend).permit(
        :date, :day_unknown, :month_unknown,
        :snapshot_date,
        :publish_start_at, :active,
        :title, :content,
        :quote, :quote_title, :quote_url,
        :via_name, :via_url,
        :unit_phenomenon, :person_phenomenon, :etc_phenomenon,
        units_json: {},
        people_json: {}
      ).tap do |whitelisted|
        whitelisted[:units] = parse_json_field(params[:trend][:units_json])
        whitelisted[:people] = parse_json_field(params[:trend][:people_json])
        whitelisted.delete(:units_json)
        whitelisted.delete(:people_json)
        whitelisted[:snapshot_date] = nil if whitelisted[:snapshot_date].blank?
      end
    end

    def trend_params_for_new
      params[:trend]&.permit(:unit_id, :person_id) || {}
    end

    def parse_json_field(json_string)
      return nil if json_string.blank?

      JSON.parse(json_string)
    rescue JSON::ParserError
      nil
    end

    def set_snapshots_from_trend
      units = @trend.units || []
      return unless units.size == 1

      unit = Unit.find_by(id: units.first['unit_id'])
      return unless unit

      @snapshots = unit.unit_snapshots
                       .includes(snapshot_people: :person)
                       .where.not(snapshot_date: nil)
                       .order(snapshot_date: :asc)
    end
  end
end
