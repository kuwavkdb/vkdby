class UnitHistoryGroupComponent < ViewComponent::Base
  def initialize(date:, logs:)
    @date = date
    @logs = logs
  end
end
