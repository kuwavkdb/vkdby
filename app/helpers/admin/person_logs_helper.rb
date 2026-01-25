# frozen_string_literal: true

module Admin
  module PersonLogsHelper
    # Convert wiki-style links [text|url] to HTML links
    def format_wiki_history_item(text)
      # Replace [text|url] with HTML link
      formatted = text.gsub(/\[([^\]|]+)\|([^\]]+)\]/) do
        link_text = ::Regexp.last_match(1)
        url = ::Regexp.last_match(2)
        link_to(link_text, url, target: '_blank', rel: 'noopener noreferrer',
                                 class: 'text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 underline')
      end

      # Sanitize and mark as HTML safe
      sanitize(formatted, tags: %w[a], attributes: %w[href target rel class])
    end
  end
end
