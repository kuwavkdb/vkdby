# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @resource = Unit.includes(:links, unit_people: :person).find_by(key: params[:key]) ||
                Person.includes(:person_logs, :links).find_by!(key: params[:key])

    @links = @resource.links.where(active: true).order(:sort_order)

    if @resource.is_a?(Person)
      @logs = @resource.person_logs.order(:sort_order, :log_date)

      # person_logsが無く、old_historyがある場合はパースして使用
      @old_history_items = @resource.parse_old_history if @logs.empty? && @resource.old_history.present?
    elsif @resource.is_a?(Unit)
      members = @resource.unit_people.includes(person: { person_logs: :unit })
      @active_members = members.select { |m| m.pre? || m.active? }
      @past_members = members.reject { |m| m.pre? || m.active? }

      # ユニットの履歴を統合 (UnitLog + PersonLog)
      unit_logs = @resource.unit_logs
      person_logs = @resource.person_logs.includes(:person)
      @history = (unit_logs + person_logs).sort_by { |l| [l.log_date.to_s, l.is_a?(PersonLog) ? 1 : 0] }
    end

    respond_to do |format|
      format.html
      format.json { render json: @resource }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { render file: Rails.root.join('public/404.html'), status: :not_found, layout: false }
      format.json { render json: { error: 'Resource not found' }, status: :not_found }
    end
  end
end
