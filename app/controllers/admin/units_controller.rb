# frozen_string_literal: true

module Admin
  class UnitsController < Admin::BaseController
    before_action :set_unit, only: %i[edit update destroy]
    before_action :require_super_operator, only: %i[destroy]

    def index
      @units = Unit.all.order(updated_at: :desc)
    end

    def new
      @unit = Unit.new(params[:unit]&.permit(:name, :key, :name_kana, :status, :unit_type, :old_key))
      @unit.name ||= params[:name]
      @unit.old_key ||= params[:old_key]
    end

    def edit
      @unit_logs = @unit.unit_logs.order(:log_date)
      @unit_people = @unit.unit_people.includes(:person).order(:period, :order_in_period)
      @unit_person = @unit.unit_people.build(period: 1, order_in_period: (@unit_people.last&.order_in_period || 0) + 1)
      @unit.links.build # Build an empty link for the form
    end

    def create
      @unit = Unit.new(unit_params)

      if @unit.save
        redirect_to admin_units_path, notice: 'Unit created successfully.'
      else
        @unit.links.build if @unit.links.none?(&:new_record?)
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @unit.update(unit_params)
        redirect_to admin_units_path, notice: 'Unit updated successfully.'
      else
        @unit_logs = @unit.unit_logs.order(:log_date)
        @unit_people = @unit.unit_people.includes(:person).order(:period, :order_in_period)
        @unit_person = @unit.unit_people.build(period: 1,
                                               order_in_period: (@unit_people.last&.order_in_period || 0) + 1)
        @unit.links.build if @unit.links.none?(&:new_record?)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @unit.destroy
      redirect_to admin_units_path, notice: 'Unit deleted successfully.'
    end

    private

    def set_unit
      @unit = Unit.find(params[:id])
    end

    def unit_params
      params.require(:unit).permit(:name, :name_kana, :key, :status, :unit_type, :old_key,
                                   links_attributes: %i[id text url active sort_order _destroy],
                                   name_logs_attributes: %i[name name_kana])
    end
  end
end
