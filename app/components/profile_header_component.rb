# frozen_string_literal: true

class ProfileHeaderComponent < ViewComponent::Base
  def initialize(resource:)
    @resource = resource
  end

  private

  def bg_class
    @resource.is_a?(Unit) ? 'bg-unit' : 'bg-person'
  end

  def name
    @resource.name
  end

  def name_kana
    @resource.name_kana
  end
end
