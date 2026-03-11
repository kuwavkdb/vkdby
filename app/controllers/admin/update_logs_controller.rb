# frozen_string_literal: true

module Admin
  class UpdateLogsController < Admin::BaseController
    before_action :require_super_operator
    before_action :set_log

    def restore
      record = @log.loggable
      return redirect_back(fallback_location: admin_root_path, alert: '対象レコードが存在しません') unless record

      case @log.action
      when 'update'
        restore_attrs = @log.diff.transform_values { |before_after| before_after[0] }.except('id', 'created_at')
        if record.update(restore_attrs)
          record_update_log(record, action: 'update')
          redirect_back fallback_location: admin_root_path, notice: '一つ前の状態に復元しました'
        else
          redirect_back fallback_location: admin_root_path, alert: '復元に失敗しました'
        end
      when 'discard'
        record.undiscard
        record_update_log(record, action: 'undiscard')
        redirect_back fallback_location: admin_root_path, notice: '復元しました（削除を取り消しました）'
      when 'undiscard'
        record.discard
        record_update_log(record, action: 'discard')
        redirect_back fallback_location: admin_root_path, notice: '復元しました（削除状態に戻しました）'
      else
        redirect_back fallback_location: admin_root_path, alert: 'この操作は復元できません'
      end
    end

    private

    def set_log
      @log = UpdateLog.find(params[:id])
    end
  end
end
