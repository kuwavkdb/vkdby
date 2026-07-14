# frozen_string_literal: true

# Marks a resource as unpublished when tagged with one of the configured
# unpublished tag IDs (see config.unpublished_tag_ids, issue #919).
module Unpublishable
  extend ActiveSupport::Concern

  def unpublished?
    tag_indices.where(id: Rails.application.config.unpublished_tag_ids).exists?
  end
end
