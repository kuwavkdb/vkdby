# frozen_string_literal: true

class SectionComponent < ViewComponent::Base
  include WikiLinkHelper
  include ApplicationHelper
  with_collection_parameter :section

  def initialize(section:)
    super()
    @section = section
  end
end
