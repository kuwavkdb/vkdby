# frozen_string_literal: true

module WikiLinkHelper
  def format_wiki_content(text)
    return '' if text.blank?

    # Handle newlines and escaping
    # simple_format escapes the text
    formatted = simple_format(text, {}, wrapper_tag: 'div')

    parse_wiki_links(formatted)
  end

  def format_wiki_title(text, link: true)
    return '' if text.blank?

    # Just escape, no wrapping
    formatted = h(text)

    parse_wiki_links(formatted, link: link)
  end

  private

  def parse_wiki_links(text, link: true)
    # [[Display|Link]] -> Internal EUC-JP link
    formatted = text.gsub(/\[\[(.*?)\|(.*?)\]\]/) do
      display = Regexp.last_match(1)
      target = Regexp.last_match(2)
      link ? create_internal_link(display, target) : display
    end

    # [[Link]] -> Internal EUC-JP link (Display == Target)
    formatted = formatted.gsub(/\[\[([^|]+?)\]\]/) do
      target = Regexp.last_match(1)
      link ? create_internal_link(target, target) : target
    end

    # [Display|URL] -> External link
    formatted = formatted.gsub(%r{\[(.*?)\|(https?://.*?)\]}) do
      display = Regexp.last_match(1)
      url = Regexp.last_match(2)
      link ? link_to(display, url, target: '_blank', rel: 'noopener noreferrer') : display
    end

    sanitize(formatted, tags: %w[a div p br], attributes: %w[href target rel class])
  end

  def create_internal_link(display, target)
    encoded = URI.encode_www_form_component(target.encode('EUC-JP'))
    link_to(display, "/#{encoded}.html")
  rescue Encoding::UndefinedConversionError
    link_to(display, '#')
  end
end
