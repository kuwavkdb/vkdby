# frozen_string_literal: true

module Admin
  class SnapshotPeopleController < Admin::BaseController
    before_action :set_unit
    before_action :set_unit_snapshot
    before_action :set_snapshot_person, only: %i[edit update destroy create_person]

    def create
      @snapshot_person = @unit_snapshot.snapshot_people.build(snapshot_person_params)

      if @snapshot_person.save
        record_update_log(@snapshot_person, action: 'create', subject: @unit)
        record_merged_sns_links(@snapshot_person)
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
        record_update_log(@snapshot_person, action: 'update', subject: @unit)
        record_merged_sns_links(@snapshot_person)
        redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                    notice: 'Member was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @snapshot_person.discard
      record_update_log(@snapshot_person, action: 'discard', subject: @unit)
      redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                  notice: 'Member was successfully removed.'
    end

    def create_person
      return redirect_to snapshot_person_path, alert: 'Person Key を設定してから実行してください。' if @snapshot_person.person_key.blank?
      return redirect_to snapshot_person_path, alert: 'すでにPersonと紐付けられています。' if @snapshot_person.person_id.present?

      person = @snapshot_person.build_person_for_independence

      if person.save
        @snapshot_person.update(person_id: person.id)
        record_update_log(person, action: 'create')
        record_update_log(@snapshot_person, action: 'update', subject: @unit)
        record_merged_sns_links(@snapshot_person)
        redirect_to snapshot_person_path, notice: 'Personを新規作成して紐付けました。'
      else
        redirect_to snapshot_person_path, alert: "Personの作成に失敗しました: #{person.errors.full_messages.join(', ')}"
      end
    rescue ActiveRecord::RecordNotUnique
      redirect_to snapshot_person_path, alert: 'そのPerson Keyはすでに使用されています。既存のPersonへの紐付けをご確認ください。'
    end

    def reorder
      params[:ids].each_with_index do |id, index|
        @unit_snapshot.snapshot_people.find(id).update(sort_order: index + 1)
      end
      head :ok
    end

    def copy_or_move
      target_snapshot = @unit_snapshot.siblings.find_by(id: params[:target_unit_snapshot_id])
      snapshot_people = @unit_snapshot.snapshot_people.where(id: Array(params[:snapshot_person_ids]))
      if target_snapshot.nil? || snapshot_people.empty?
        return redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                           alert: 'コピー・移動先のスナップショットと、コピー・移動するメンバーを選択してください。'
      end

      SnapshotPersonCopyMover.new(snapshot_people, target_snapshot, params[:mode]).call do |record, action|
        record_update_log(record, action: action, subject: @unit)
      end
      redirect_to edit_admin_unit_unit_snapshot_path(@unit, @unit_snapshot),
                  notice: "#{snapshot_people.size}件のメンバーを#{params[:mode] == 'move' ? '移動' : 'コピー'}しました。"
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

    def snapshot_person_path
      edit_admin_unit_unit_snapshot_snapshot_person_path(@unit, @unit_snapshot, @snapshot_person)
    end

    def snapshot_person_params
      p = params.require(:snapshot_person).permit(
        :person_id, :person_name, :part, :part_alias,
        :status, :support, :sort_order, :person_key,
        :inline_history, :sns,
        extra_profile: %i[birthday birth_year blood hometown]
      )
      p[:person_id] = nil if p[:person_id].to_i.zero?
      # extra_profile も inline_history と同じく、Person未紐付けのメンバーの下書き情報のため、
      # 紐付け済みの場合は編集させない（issue #1619）
      %i[inline_history extra_profile].each { |key| p.delete(key) } if p[:person_id].present?

      if p[:sns].is_a?(String)
        p[:sns] = p[:sns].split("\n").map(&:strip).reject(&:blank?)
        p[:sns] = nil if p[:sns].empty?
      end

      p[:extra_profile] = p[:extra_profile].to_h.compact_blank.presence if p[:extra_profile].is_a?(ActionController::Parameters)

      p
    end
  end
end
