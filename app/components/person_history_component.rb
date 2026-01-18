class PersonHistoryComponent < ViewComponent::Base
  def initialize(person:, logs:)
    @person = person
    @logs = logs
  end

  def render?
    @logs.present?
  end
end
