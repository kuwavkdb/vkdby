class PersonHistoryItemComponent < ViewComponent::Base
  def initialize(log:)
    @log = log
  end

  def render?
    @log.present?
  end
end
