class HistoryComponent < ViewComponent::Base
  def initialize(logs:, resource: nil)
    @logs = logs
    @resource = resource
  end

  def render?
    @logs.present?
  end
end
