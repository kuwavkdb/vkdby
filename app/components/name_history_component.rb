# frozen_string_literal: true

# Displays the name history timeline for a Unit or Person
class NameHistoryComponent < ViewComponent::Base
  def initialize(resource:)
    super()
    @resource = resource
  end

  def render?
    @resource.name_logs.present?
  end

  def name_logs
    @resource.name_logs.sort_by { |log| log.date.to_s }
  end
end
