# frozen_string_literal: true

class SectionComponent < ViewComponent::Base
  include WikiLinkHelper
  with_collection_parameter :section

  def initialize(section:)
    @section = section
  end
end
