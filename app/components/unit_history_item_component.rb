class UnitHistoryItemComponent < ViewComponent::Base
  with_collection_parameter :log
  def initialize(log:, grouped: false)
    @log = log
    @grouped = grouped
  end

  def render?
    @log.present?
  end
end
