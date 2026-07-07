# frozen_string_literal: true

class YoutubeEmbedComponentPreview < ViewComponent::Preview
  layout 'component_preview'
  def default
    links = [mock_link('https://youtube.com/watch?v=dQw4w9WgXcQ')]
    render(YoutubeEmbedComponent.new(links: links))
  end

  def multiple_videos
    links = [
      mock_link('https://youtube.com/watch?v=dQw4w9WgXcQ'),
      mock_link('https://youtu.be/XjFviZsK9Yk'),
      mock_link('https://youtu.be/ze-cHnIJohY')
    ]
    render(YoutubeEmbedComponent.new(links: links))
  end

  def no_links
    render(YoutubeEmbedComponent.new(links: []))
  end

  private

  def mock_link(url)
    Link.new(
      url: url,
      linkable: Person.new
    )
  end
end
