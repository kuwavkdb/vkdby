# frozen_string_literal: true

class ManagementInformationComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end
end
