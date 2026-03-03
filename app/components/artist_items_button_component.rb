# frozen_string_literal: true

class ArtistItemsButtonComponent < ViewComponent::Base
  def initialize(artist_name:, old_key: nil, key: nil)
    super()
    @artist_name = artist_name
    @old_key = old_key
    @key = key
  end

  def render?
    @old_key.present? || @key.present?
  end
end
