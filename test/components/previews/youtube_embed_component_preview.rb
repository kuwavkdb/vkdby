# frozen_string_literal: true

class YoutubeEmbedComponentPreview < ViewComponent::Preview
  layout 'component_preview'
  def default
    link = mock_link('https://youtube.com/watch?v=dQw4w9WgXcQ')
    render(YoutubeEmbedComponent.new(link: link))
  end

  def no_link
    render(YoutubeEmbedComponent.new(link: nil))
  end

  private

  def mock_link(url)
    Link.new(
      url: url,
      linkable: Person.new
    )
  end
end
