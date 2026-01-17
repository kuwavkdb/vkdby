class HistoryComponent < ViewComponent::Base
  def initialize(logs:)
    @logs = logs
  end

  def render?
    @logs.present?
  end
end
