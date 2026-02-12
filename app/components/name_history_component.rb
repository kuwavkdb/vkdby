# frozen_string_literal: true

# Displays the name history timeline for a Unit or Person
class NameHistoryComponent < ViewComponent::Base
  def initialize(resource:)
    super()
    @resource = resource
  end

  def render?
    name_logs.present? && name_logs.size > 1
  end

  def name_logs
    @resource.name_logs.sort_by { |log| log.date.to_s }
  end
end
