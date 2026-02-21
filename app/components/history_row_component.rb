# frozen_string_literal: true

class HistoryRowComponent < ViewComponent::Base
  with_collection_parameter :concurrent_items

  def initialize(concurrent_items:)
    @concurrent_items = concurrent_items
  end
end
