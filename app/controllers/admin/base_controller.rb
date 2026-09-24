# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :require_login
    # layout 'admin' # Use default implementation for now until layout is created

    private

    def require_admin
      return if current_user&.admin?

      redirect_to root_path, alert: '権限がありません'
    end

    def require_super_operator
      return if current_user&.super_operator_or_above?

      redirect_to admin_root_path, alert: '権限がありません'
    end

    # subjectは、この編集をどのページの更新として扱うかを表す。省略時はrecord自身
    # （Unit/Person/CustomPageの直接編集）。Link/Section等のネストしたレコードを
    # 編集する呼び出し元では、親ページを明示的に渡す（issue #1530）。
    def record_update_log(record, action:, subject: record)
      diff = case action
             when 'create'
               record.saved_changes.except('created_at', 'updated_at')
             when 'update', 'change_key'
               record.saved_changes.except('updated_at')
             end

      UpdateLog.create!(
        user: current_user,
        action: action,
        loggable: record,
        subject: subject,
        diff: diff
      )

      Rails.cache.delete(SidebarLoadable::RECENTLY_UPDATED_CACHE_KEY)
    end

    # SnapshotPersonの紐付けに伴い、snsからPerson#linksへ追加されたLinkを記録する（issue #1654）
    def record_merged_sns_links(snapshot_person)
      Array(snapshot_person.merged_links).each do |link|
        record_update_log(link, action: 'create', subject: link.linkable)
      end
    end
  end
end
