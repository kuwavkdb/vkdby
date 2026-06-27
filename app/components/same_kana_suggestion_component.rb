# frozen_string_literal: true

class SameKanaSuggestionComponent < ViewComponent::Base
  def initialize(resource:, same_kana_resources:, same_kana_total:)
    super()
    @resource = resource
    @same_kana_resources = same_kana_resources
    @same_kana_total = same_kana_total
  end

  def render?
    @same_kana_resources.present?
  end

  private

  def search_path
    if @resource.is_a?(Unit)
      helpers.units_path(q: @resource.name_kana, anchor: 'results')
    else
      helpers.people_path(q: @resource.name_kana, anchor: 'results')
    end
  end

  def remaining_count
    @same_kana_total - @same_kana_resources.size
  end
end
