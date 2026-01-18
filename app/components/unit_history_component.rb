class UnitHistoryComponent < ViewComponent::Base
  def initialize(unit:, logs:)
    @unit = unit
    @logs = logs
  end

  def render?
    @logs.present?
  end
end
