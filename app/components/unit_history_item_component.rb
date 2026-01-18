class UnitHistoryItemComponent < ViewComponent::Base
  with_collection_parameter :log
  def initialize(log:)
    @log = log
  end

  def render?
    @log.present?
  end
end
