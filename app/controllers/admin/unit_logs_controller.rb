# frozen_string_literal: true

module Admin
  class UnitLogsController < Admin::BaseController
    before_action :set_unit
    before_action :set_unit_log, only: %i[edit update destroy]

    def index
      @unit_logs = @unit.unit_logs.order(:log_date)
    end

    def new
      @unit_log = @unit.unit_logs.build
    end

    def edit; end

    def create
      @unit_log = @unit.unit_logs.build(unit_log_params)

      if @unit_log.save
        redirect_to admin_unit_unit_logs_path(@unit), notice: 'Unit log was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @unit_log.update(unit_log_params)
        redirect_to admin_unit_unit_logs_path(@unit), notice: 'Unit log was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @unit_log.destroy
      redirect_to admin_unit_unit_logs_path(@unit), notice: 'Unit log was successfully destroyed.'
    end

    private

    def set_unit
      @unit = Unit.find(params[:unit_id])
    end

    def set_unit_log
      @unit_log = @unit.unit_logs.find(params[:id])
    end

    def unit_log_params
      params.require(:unit_log).permit(:log_date, :phenomenon, :phenomenon_alias, :text, :source_url, :quote_text)
    end
  end
end
