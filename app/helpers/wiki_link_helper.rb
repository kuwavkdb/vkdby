# frozen_string_literal: true

module WikiLinkHelper # rubocop:disable Metrics/ModuleLength
  def format_wiki_content(text)
    return '' if text.blank?

    blocks = parse_wiki_lines(text)
    render_wiki_blocks(blocks)
  end

  def render_wiki_list(lines)
    html = ''.html_safe
    current_depth = 0

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

  def render_wiki_dl(lines)
    content = lines.map do |line|
      if line =~ /^:(.+?):(.*)$/
        term = Regexp.last_match(1)
        desc = Regexp.last_match(2)
        dt = tag.dt(class: 'text-sm font-semibold text-slate-500 dark:text-slate-400 mt-2') { parse_wiki_links(term) }
        dd = tag.dd(class: 'text-slate-700 dark:text-slate-300 ml-4 mb-2') { parse_wiki_links(desc) }
        dt + dd
      else
        ''
      end
    end.join.html_safe

    tag.dl(class: 'space-y-1 mt-8 mb-4') { content }
  end

  def render_wiki_multi_dl(lines)
    content = lines.map do |line|
      if line.match?(/^:::(.*)$/)
        desc = line.sub(/^:::/, '').strip
        tag.dd(class: 'text-slate-700 dark:text-slate-300 ml-4 mb-2') { parse_wiki_links(desc) }
      elsif line.match?(/^::(.*)$/)
        term = line.sub(/^::/, '').strip
        tag.dt(class: 'text-sm font-semibold text-slate-500 dark:text-slate-400 mt-2') { parse_wiki_links(term) }
      else
        ''
      end
    end.join.html_safe

    tag.dl(class: 'space-y-1 mt-8 mb-4') { content }
  end

  def format_wiki_title(text, link: true)
    return '' if text.blank?

    # Just escape, no wrapping
    formatted = h(text)

    parse_wiki_links(formatted, link: link)
  end

  def sanitize_with_ruby(text)
    return '' if text.blank?

    sanitize(text, tags: %w[ruby rt span], attributes: %w[class]).html_safe
  end

  private

  def parse_wiki_lines(text)
    blocks = []
    current_block = { type: :text, lines: [] }
    in_blockquote = false

    text.each_line do |line|
      if in_blockquote
        if line.match?(/^\}\}/)
          blocks << current_block
          current_block = { type: :text, lines: [] }
          in_blockquote = false
        else
          current_block[:lines] << line
        end
        next
      end

      if line.match?(/^\{\{bq/)
        blocks << current_block unless current_block[:lines].empty?
        # 先頭行にTwitter URLが含まれる場合はtweet_embedタイプとして扱う
        tweet_url = line.match(%r{https?://(?:twitter\.com|x\.com)/\S+})&.to_s
        block_type = tweet_url ? :tweet_embed : :blockquote
        current_block = { type: block_type, lines: [] }
        in_blockquote = true
        next
      end

      process_line(line, blocks, current_block) do |new_block|
        current_block = new_block
      end
    end
    blocks << current_block unless current_block[:lines].empty?
    blocks
  end

  def process_line(line, blocks, current_block, &block)
    case line
    when /^!/
      handle_h3(line, blocks, current_block, &block)
    when /^::/
      handle_multi_dl(line, blocks, current_block, &block)
    when /^\s*\*/
      handle_list(line, blocks, current_block, &block)
    when /^:(.+?):(.*)$/
      handle_dl(line, blocks, current_block, &block)
    when /\{\{youtube2\s+([^,}\s]+)/i
      handle_youtube2(line, blocks, current_block, &block)
    else
      handle_text(line, blocks, current_block, &block)
    end
  end

  def handle_h3(line, blocks, current_block)
    blocks << current_block unless current_block[:lines].empty?
    content = line.sub(/^!\s*/, '').strip
    yield({ type: :h3, lines: [content] })
  end

  def handle_multi_dl(line, blocks, current_block)
    if current_block[:type] == :multi_dl
      current_block[:lines] << line
    else
      blocks << current_block unless current_block[:lines].empty?
      yield({ type: :multi_dl, lines: [line] })
    end
  end

  def handle_list(line, blocks, current_block)
    if current_block[:type] == :list
      current_block[:lines] << line
    else
      blocks << current_block unless current_block[:lines].empty?
      yield({ type: :list, lines: [line] })
    end
  end

  def handle_dl(line, blocks, current_block)
    if current_block[:type] == :definition_list
      current_block[:lines] << line
    else
      blocks << current_block unless current_block[:lines].empty?
      yield({ type: :definition_list, lines: [line] })
    end
  end

  def handle_text(line, blocks, current_block)
    if current_block[:type] == :text
      current_block[:lines] << line
    else
      blocks << current_block unless current_block[:lines].empty?
      yield({ type: :text, lines: [line] })
    end
  end

  def handle_youtube2(line, blocks, current_block, &block)
    video_id = line.match(/\{\{youtube2\s+([^,}\s]+)/i)&.captures&.first&.strip
    return handle_text(line, blocks, current_block, &block) unless video_id

    blocks << current_block unless current_block[:lines].empty?
    block.call({ type: :youtube2, video_id: video_id, lines: [line] })
  end

  def render_wiki_blocks(blocks)
    safe_join(blocks.map do |block|
      case block[:type]
      when :h3
        content = block[:lines].first
        tag.h3(class: 'text-lg font-bold mt-6 mb-2 text-slate-800 dark:text-slate-200 border-l-4 border-slate-500 pl-2') do
          parse_wiki_links(content)
        end
      when :list
        render_wiki_list(block[:lines])
      when :tweet_embed
        render_tweet_embed(block[:lines].join)
      when :blockquote
        content = block[:lines].join
        tag.blockquote(class: 'border-l-4 border-slate-300 dark:border-slate-600 pl-4 italic text-slate-600 dark:text-slate-400 my-4') do
          parse_wiki_links(simple_format(content))
        end
      when :definition_list
        render_wiki_dl(block[:lines])
      when :multi_dl
        render_wiki_multi_dl(block[:lines])
      when :youtube2
        video_id = block[:video_id]
        tag.div(class: 'relative pb-[56.25%] h-0 overflow-hidden rounded-xl my-4') do
          tag.iframe(src: "https://www.youtube.com/embed/#{video_id}",
                     frameborder: '0',
                     allow: 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture',
                     allowfullscreen: true,
                     class: 'absolute top-0 left-0 w-full h-full border-0')
        end
      else
        text_content = block[:lines].join
        formatted = simple_format(text_content, {}, wrapper_tag: 'div')
        parse_wiki_links(formatted)
      end
    end)
  end

  def parse_wiki_links(text, link: true)
    # Placeholder for protected links
    placeholders = {}

    # 1. Protect wiki links [[...]] and [...]
    # [[Display|Link]]
    protected_text = text.gsub(/\[\[([^\[\]|]+)\|([^\[\]]+)\]\]/) do
      key = "WIKILINKPLACEHOLDER#{placeholders.size}"
      display = Regexp.last_match(1)
      target = Regexp.last_match(2)
      placeholders[key] = link ? create_internal_link(display, target) : display
      key
    end

    # [[Link]]
    protected_text = protected_text.gsub(/\[\[([^\[\]|]+)\]\]/) do
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

    # 4. Parse rb plugin {{rb Text,Ruby}}
    protected_text = protected_text.gsub(/\{\{rb\s+([^,]+),([^}]+)\}\}/) do
      text_part = Regexp.last_match(1).strip
      ruby_part = Regexp.last_match(2).strip
      "<ruby>#{text_part}<rt>#{ruby_part}</rt></ruby>"
    end

    # 3. Restore protected links
    placeholders.each do |key, value|
      protected_text.gsub!(key, value)
    end

    sanitize(protected_text, tags: %w[a div p br ul li dt dd dl blockquote ruby rt], attributes: %w[href target rel class])
  end

  def create_internal_link(display, target)
    encoded = URI.encode_www_form_component(target.encode('EUC-JP'))
    link_to(display.html_safe, "/#{encoded}.html", class: 'text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 underline')
  rescue Encoding::UndefinedConversionError
    link_to(display.html_safe, '#', class: 'text-indigo-600 hover:text-indigo-800 dark:text-indigo-400 dark:hover:text-indigo-300 underline')
  end

  # Twitter tweet embedを出力する
  # <blockquote class="twitter-tweet"> をサニタイズしつつそのまま出力し、
  # Twitter widget scriptを付加する
  def render_tweet_embed(content)
    sanitized = sanitize(
      content,
      tags: %w[blockquote a p br],
      attributes: %w[class lang href]
    )
    script = tag.script(src: '//platform.twitter.com/widgets.js', async: true, charset: 'utf-8')
    (sanitized + script).html_safe
  end
end
