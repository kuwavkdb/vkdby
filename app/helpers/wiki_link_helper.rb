# frozen_string_literal: true

module WikiLinkHelper
  def format_wiki_content(text)
    return '' if text.blank?

    blocks = []
    current_block = { type: :text, lines: [] }

    text.each_line do |line|
      is_list_item = line.match?(/^\s*\*/)

      if is_list_item
        if current_block[:type] == :list
          current_block[:lines] << line
        else
          blocks << current_block unless current_block[:lines].empty?
          current_block = { type: :list, lines: [line] }
        end
      elsif current_block[:type] == :text
        current_block[:lines] << line
      else
        blocks << current_block unless current_block[:lines].empty?
        current_block = { type: :text, lines: [line] }
      end
    end
    blocks << current_block unless current_block[:lines].empty?

    safe_join(blocks.map do |block|
      if block[:type] == :list
        render_wiki_list(block[:lines])
      else
        text_content = block[:lines].join
        formatted = simple_format(text_content, {}, wrapper_tag: 'div')
        parse_wiki_links(formatted)
      end
    end)
  end

  def render_wiki_list(lines)
    html = ''.html_safe
    current_depth = 0

    # Simple list renderer that handles nesting by opening/closing ULs
    # Strictly valid HTML (ul inside li) is hard with line-based parsing without recursion/lookahead
    # This implementation produces <ul><ul>...</ul></ul> for nesting which is widely supported

    lines.each do |line|
      depth = line[/\A\s*(\*+)/, 1]&.length || 0
      content = line.sub(/\A\s*\*+\s*/, '')
      parsed_content = parse_wiki_links(h(content))

      if depth > current_depth
        (depth - current_depth).times do
          html << '<ul class="list-disc list-inside ml-4 text-slate-700 dark:text-slate-300">'.html_safe
        end
      elsif depth < current_depth
        (current_depth - depth).times do
          html << '</ul>'.html_safe
        end
      end

      html << "<li>#{parsed_content}</li>".html_safe
      current_depth = depth
    end

    current_depth.times { html << '</ul>'.html_safe }

    html
  end

  def format_wiki_title(text, link: true)
    return '' if text.blank?

    # Just escape, no wrapping
    formatted = h(text)

    parse_wiki_links(formatted, link: link)
  end

  private

  def parse_wiki_links(text, link: true)
    # Placeholder for protected links
    placeholders = {}

    # 1. Protect wiki links [[...]] and [...]
    # [[Display|Link]]
    protected_text = text.gsub(/\[\[(.*?)\|(.*?)\]\]/) do
      key = "WIKILINKPLACEHOLDER#{placeholders.size}"
      display = Regexp.last_match(1)
      target = Regexp.last_match(2)
      placeholders[key] = link ? create_internal_link(display, target) : display
      key
    end

    # [[Link]]
    protected_text = protected_text.gsub(/\[\[([^|]+?)\]\]/) do
      key = "WIKILINKPLACEHOLDER#{placeholders.size}"
      target = Regexp.last_match(1)
      placeholders[key] = link ? create_internal_link(target, target) : target
      key
    end

    # [Display|URL]
    protected_text = protected_text.gsub(%r{\[(.*?)\|(https?://.*?)\]}) do
      key = "WIKILINKPLACEHOLDER#{placeholders.size}"
      display = Regexp.last_match(1)
      url = Regexp.last_match(2)
      link_class = 'text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 underline'
      placeholders[key] = link ? link_to(display, url, target: '_blank', rel: 'noopener noreferrer', class: link_class) : display
      key
    end

    # 2. Auto-link raw URLs in the remaining text
    if link
      protected_text = protected_text.gsub(URI::DEFAULT_PARSER.make_regexp(%w[http https])) do |match|
        link_class = 'text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 underline'
        link_to(match, match, target: '_blank', rel: 'noopener noreferrer', class: link_class)
      end
    end

    # 3. Restore protected links
    placeholders.each do |key, value|
      protected_text.gsub!(key, value)
    end

    sanitize(protected_text, tags: %w[a div p br ul li], attributes: %w[href target rel class])
  end

  def create_internal_link(display, target)
    encoded = URI.encode_www_form_component(target.encode('EUC-JP'))
    link_to(display, "/#{encoded}.html", class: 'text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 underline')
  rescue Encoding::UndefinedConversionError
    link_to(display, '#', class: 'text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 underline')
  end
end
