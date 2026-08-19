# frozen_string_literal: true

class TwitterEmbedComponentPreview < ViewComponent::Preview
  layout 'component_preview'
  def default
    links = [mock_link('https://x.com/nonameactorsjp/status/892008297930268674')]
    render(TwitterEmbedComponent.new(links: links))
  end

  def multiple_tweets
    links = [
      mock_link('https://x.com/nonameactorsjp/status/892008297930268674'),
      mock_link('https://twitter.com/nonameactorsjp/status/892008297930268674')
    ]
    render(TwitterEmbedComponent.new(links: links))
  end

  def no_links
    render(TwitterEmbedComponent.new(links: []))
  end

  private

  def mock_link(url)
    Link.new(
      url: url,
      linkable: Person.new
    )
  end
end
