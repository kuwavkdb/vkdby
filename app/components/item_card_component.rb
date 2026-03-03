# frozen_string_literal: true

class ItemCardComponent < ViewComponent::Base
  include ItemsHelper

  def initialize(item_card:)
    super()
    @item = item_card
  end

  def render?
    @item.present?
  end
end
