# frozen_string_literal: true

module Admin
  class TemporarySnapshotPeopleController < Admin::BaseController
    before_action :set_temporary_snapshot_person, only: %i[destroy assign]

    def index
      @temporary_snapshot_people = TemporarySnapshotPerson.includes(:person, :hint_unit).order(:created_at)
      @unit = Unit.kept.find_by(id: params[:unit_id])
      @temporary_snapshot_people = @temporary_snapshot_people.where(hint_unit_id: @unit.id) if @unit

      @assigned_unit = Unit.kept.find_by(id: params[:assigned_unit_id])
      @assigned_unit_snapshots = if @assigned_unit
                                   @assigned_unit.unit_snapshots.where(id: Array(params[:assigned_unit_snapshot_ids]))
                                 else
                                   UnitSnapshot.none
                                 end
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

      target_snapshots = build_target_snapshots
      if target_snapshots.empty?
        render_assign_errors(['振り分け先のスナップショットを1つ以上選択してください。'])
        return
      end

      snapshot_people = target_snapshots.map { |snapshot| snapshot.snapshot_people.build(snapshot_person_attributes) }

      if target_snapshots.all?(&:valid?)
        save_assignment(target_snapshots, snapshot_people)
      else
        render_assign_errors(target_snapshots.flat_map { |s| s.errors.full_messages }.uniq)
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

    def build_target_snapshots
      selected_ids = Array(params[:unit_snapshot_ids]).reject(&:blank?)
      create_new = ActiveModel::Type::Boolean.new.cast(params[:create_new_snapshot])

      target_snapshots = @unit.unit_snapshots.where(id: selected_ids).to_a
      target_snapshots << @unit.unit_snapshots.new(current: false, active: false, past: true) if create_new
      target_snapshots
    end

    def save_assignment(target_snapshots, snapshot_people)
      ActiveRecord::Base.transaction { target_snapshots.each(&:save!) }
      snapshot_people.each { |sp| record_update_log(sp, action: 'create') }
      @temporary_snapshot_person.destroy

      redirect_to admin_temporary_snapshot_people_path(
        assigned_unit_id: @unit.id,
        assigned_unit_snapshot_ids: snapshot_people.map(&:unit_snapshot_id)
      ), notice: "#{@unit.name} の#{snapshot_people.size}件のスナップショットへ振り分けました。"
    end

    def render_assign_errors(messages)
      @unit_snapshots = @unit.unit_snapshots.chronological
      flash.now[:alert] = "振り分けに失敗しました: #{messages.join('、')}"
      render :assign, status: :unprocessable_entity
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
