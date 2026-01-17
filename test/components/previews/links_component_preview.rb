class LinksComponentPreview < ViewComponent::Preview
  layout "component_preview"
  def default
    links = [
      mock_link("Official Site", "https://example.com"),
      mock_link("Twitter", "https://twitter.com/example"),
      mock_link("X", "https://x.com/example"),
      mock_link("Instagram", "https://instagram.com/example")
    ]
    render(LinksComponent.new(links: links))
  end

  def with_youtube_embed
    links = [
      mock_link("Official Site", "https://example.com"),
      mock_link("YouTube Music Video", "https://youtube.com/watch?v=dQw4w9WgXcQ"),
      mock_link("Twitter", "https://twitter.com/example")
    ]
    render(LinksComponent.new(links: links))
  end

  def no_links
    render(LinksComponent.new(links: []))
  end

  private

  def mock_link(display_text, url)
    Link.new(
      text: display_text,
      url: url,
      linkable: Person.new # dummy linkable to satisfy potential needs, though not strictly required for display logic
    )
  end
end
