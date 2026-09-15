# frozen_string_literal: true

# Basic Information セクション内の label/value 1行分を表示する
class BasicAttributeItemComponent < ViewComponent::Base
  with_collection_parameter :item

  def initialize(item:, item_counter:)
    super()
    @item = item
    @index = item_counter
  end
end
