# frozen_string_literal: true

module LoggableLinkChanges
  extend ActiveSupport::Concern

  private

  def record_link_changes(unit, pre_link_ids)
    unit.links.each do |link|
      if pre_link_ids.include?(link.id)
        record_update_log(link, action: 'update') if link.saved_changes.except('updated_at').any?
      else
        record_update_log(link, action: 'create')
      end
    end

    destroyed_ids = pre_link_ids - unit.links.map(&:id)
    destroyed_ids.each do |link_id|
      UpdateLog.create!(user: current_user, action: 'discard',
                        loggable_type: 'Link', loggable_id: link_id, diff: nil)
    end
  end
end
