# frozen_string_literal: true

class SectionComponent < ViewComponent::Base
  include WikiLinkHelper
  include ApplicationHelper
  with_collection_parameter :section

  def initialize(section:, admin: false)
    super()
    @section = section
    @admin = admin
  end
end
