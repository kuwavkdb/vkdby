# frozen_string_literal: true

module Admin
  class TemporarySnapshotPeopleController < Admin::BaseController
    before_action :set_temporary_snapshot_person, only: %i[destroy assign]

    def index
      @temporary_snapshot_people = TemporarySnapshotPerson.includes(:person, :hint_unit).order(:created_at)
      @unit = Unit.kept.find_by(id: params[:unit_id])
      @temporary_snapshot_people = @temporary_snapshot_people.where(hint_unit_id: @unit.id) if @unit
    end

    def assign
      target_unit_id = params[:unit_id].presence || @temporary_snapshot_person.hint_unit_id
      @unit = Unit.kept.find_by(id: target_unit_id)
      @unit_snapshots = @unit ? @unit.unit_snapshots.chronological : UnitSnapshot.none

      return unless request.post?

      if @unit.nil?
        redirect_to assign_admin_temporary_snapshot_person_path(@temporary_snapshot_person),
                    alert: 'ユニットを選択してください。'
        return
      end

      unit_snapshot = target_unit_snapshot

      snapshot_person = unit_snapshot.snapshot_people.build(snapshot_person_attributes)

      if snapshot_person.save
        record_update_log(snapshot_person, action: 'create')
        @temporary_snapshot_person.destroy
        redirect_to admin_temporary_snapshot_people_path,
                    notice: "#{@unit.name} のスナップショットへ振り分けました。"
      else
        @unit_snapshots = @unit.unit_snapshots.chronological
        flash.now[:alert] = "振り分けに失敗しました: #{snapshot_person.errors.full_messages.join('、')}"
        render :assign, status: :unprocessable_entity
      end
    end

    def destroy
      @temporary_snapshot_person.destroy
      redirect_to admin_temporary_snapshot_people_path, notice: 'プールから削除しました。'
    end

    private

    def set_temporary_snapshot_person
      @temporary_snapshot_person = TemporarySnapshotPerson.find(params[:id])
    end

    def target_unit_snapshot
      if params[:unit_snapshot_id].present?
        @unit.unit_snapshots.find(params[:unit_snapshot_id])
      else
        @unit.unit_snapshots.create!(current: false, active: false, past: true)
      end
    end

    def snapshot_person_attributes
      {
        person_id: @temporary_snapshot_person.person_id,
        person_key: @temporary_snapshot_person.person_key,
        person_name: @temporary_snapshot_person.person_name,
        name_alias: params[:name_alias].presence,
        part: params[:part].presence || @temporary_snapshot_person.part,
        part_alias: params[:part_alias].presence || @temporary_snapshot_person.part_alias,
        status: params[:status].presence || @temporary_snapshot_person.status,
        support: ActiveModel::Type::Boolean.new.cast(params[:support]) || false,
        sns: @temporary_snapshot_person.sns,
        inline_history: @temporary_snapshot_person.inline_history
      }
    end
  end
end
