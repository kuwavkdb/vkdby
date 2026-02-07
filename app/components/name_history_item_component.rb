# frozen_string_literal: true

# Displays a single name history log entry with date, name, and kana
class NameHistoryItemComponent < ViewComponent::Base
  with_collection_parameter :log

  def initialize(log:)
    super()
    @log = log
  end
end
