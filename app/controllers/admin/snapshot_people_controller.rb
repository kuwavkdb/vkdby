# frozen_string_literal: true

module Admin
  class SnapshotPeopleController < Admin::BaseController
    before_action :set_unit
    before_action :set_unit_snapshot
    before_action :set_snapshot_person, only: %i[edit update destroy create_person]

    def create
      @snapshot_person = @unit_snapshot.snapshot_people.build(snapshot_person_params)

      if @snapshot_person.save
        record_update_log(@snapshot_person, action: 'create')
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    notice: 'Member was successfully added.'
      else
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    alert: "Failed to add member: #{@snapshot_person.errors.full_messages.join(', ')}"
      end
    end

    def edit; end

    def update
      if @snapshot_person.update(snapshot_person_params)
        record_update_log(@snapshot_person, action: 'update')
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    notice: 'Member was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @snapshot_person.discard
      record_update_log(@snapshot_person, action: 'discard')
      redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                  notice: 'Member was successfully removed.'
    end

    def create_person
      if @snapshot_person.person_key.blank?
        redirect_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @unit_snapshot, @snapshot_person),
                    alert: 'Person Key を設定してから実行してください。'
        return
      end

      if @snapshot_person.person_id.present?
        redirect_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @unit_snapshot, @snapshot_person),
                    alert: 'すでにPersonと紐付けられています。'
        return
      end

      person = Person.new(
        name: @snapshot_person.person_name,
        key: @snapshot_person.person_key,
        parts: @snapshot_person.part == 'unknown' ? [] : [@snapshot_person.part]
      )

      if person.save
        @snapshot_person.update(person_id: person.id)
        record_update_log(person, action: 'create')
        record_update_log(@snapshot_person, action: 'update')
        redirect_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @unit_snapshot, @snapshot_person),
                    notice: 'Personを新規作成して紐付けました。'
      else
        redirect_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @unit_snapshot, @snapshot_person),
                    alert: "Personの作成に失敗しました: #{person.errors.full_messages.join(', ')}"
      end
    rescue ActiveRecord::RecordNotUnique
      redirect_to edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @unit_snapshot, @snapshot_person),
                  alert: 'そのPerson Keyはすでに使用されています。既存のPersonへの紐付けをご確認ください。'
    end

    def reorder
      params[:ids].each_with_index do |id, index|
        @unit_snapshot.snapshot_people.find(id).update(sort_order: index + 1)
      end
      head :ok
    end

    private

    def set_unit
      @unit = Unit.find(params[:unit_id])
    end

    def set_unit_snapshot
      @unit_snapshot = @unit.unit_snapshots.find(params[:unit_snapshot_id])
    end

    def set_snapshot_person
      @snapshot_person = @unit_snapshot.snapshot_people.find(params[:id])
    end

    def snapshot_person_params
      p = params.require(:snapshot_person).permit(
        :person_id, :person_name, :name_alias, :part, :part_alias,
        :status, :support, :sort_order, :person_key, :old_person_key,
        :inline_history, :sns
      )
      p[:person_id] = nil if p[:person_id].to_i.zero?

      if p[:sns].is_a?(String)
        p[:sns] = p[:sns].split("\n").map(&:strip).reject(&:blank?)
        p[:sns] = nil if p[:sns].empty?
      end

      p
    end
  end
end
