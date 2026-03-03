# frozen_string_literal: true

class ArtistItemsButtonComponentPreview < ViewComponent::Preview
  layout 'component_preview'

  def default
    render(ArtistItemsButtonComponent.new(
             artist_name: 'lynch.',
             old_key: 'lynch.'
           ))
  end

  def with_key
    render(ArtistItemsButtonComponent.new(
             artist_name: 'SomeArtist',
             key: 'some-artist'
           ))
  end
end
