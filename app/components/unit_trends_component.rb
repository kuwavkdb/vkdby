# frozen_string_literal: true

class UnitTrendsComponent < ViewComponent::Base
  def initialize(trends:)
    super()
    @trends = trends
  end

  def render?
    @trends.present?
  end

  private

  def format_title(title)
    # [[Display|Link]] -> Internal EUC-JP link
    formatted = title.gsub(/\[\[(.*?)\|(.*?)\]\]/) do
      display = Regexp.last_match(1)
      target = Regexp.last_match(2)
      create_internal_link(display, target)
    end

    # [[Link]] -> Internal EUC-JP link (Display == Target)
    formatted = formatted.gsub(/\[\[([^|]+?)\]\]/) do
      target = Regexp.last_match(1)
      create_internal_link(target, target)
    end

    # [Display|URL] -> External link
    formatted = formatted.gsub(%r{\[(.*?)\|(https?://.*?)\]}) do
      display = Regexp.last_match(1)
      url = Regexp.last_match(2)
      link_to(display, url, target: '_blank', rel: 'noopener noreferrer')
    end

    sanitize(formatted, tags: %w[a], attributes: %w[href target rel])
  end

  def create_internal_link(display, target)
    encoded = URI.encode_www_form_component(target.encode('EUC-JP'))
    link_to(display, "/#{encoded}.html")
  rescue Encoding::UndefinedConversionError
    link_to(display, '#')
  end
end
