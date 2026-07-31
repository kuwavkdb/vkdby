# frozen_string_literal: true

# Marks a resource as unpublished when tagged with one of the configured
# unpublished tag IDs (see config.unpublished_tag_ids, issue #919).
module Unpublishable
  extend ActiveSupport::Concern

  class_methods do
    def published
      unpublished_ids = TagIndexItem.where(indexable_type: to_s,
                                           tag_index_id: Rails.application.config.unpublished_tag_ids)
                                    .select(:indexable_id)
      where.not(id: unpublished_ids)
    end
  end

  def unpublished?
    tag_indices.where(id: Rails.application.config.unpublished_tag_ids).exists?
  end
end
