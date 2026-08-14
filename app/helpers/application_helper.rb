# frozen_string_literal: true

require 'cgi'

module ApplicationHelper # rubocop:disable Metrics/ModuleLength
  class ExternalAwareHtmlRenderer < Redcarpet::Render::HTML
    def initialize(site_host:, **options)
      @site_host = site_host
      super(**options)
    end

    def link(link, title, content)
      safe_link = CGI.escapeHTML(link.to_s)
      title_attr = title.present? ? " title=\"#{CGI.escapeHTML(title)}\"" : ''
      extra_attrs = external_url?(link) ? ' target="_blank" rel="noopener noreferrer"' : ''
      "<a href=\"#{safe_link}\"#{title_attr}#{extra_attrs}>#{content}</a>"
    end

    def autolink(link, _link_type)
      safe_link = CGI.escapeHTML(link.to_s)
      extra_attrs = external_url?(link) ? ' target="_blank" rel="noopener noreferrer"' : ''
      "<a href=\"#{safe_link}\"#{extra_attrs}>#{safe_link}</a>"
    end

    private

    def external_url?(url)
      return false if url.blank? || url.start_with?('/', '#', 'mailto:')
      return true unless url.match?(%r{\Ahttps?://})

      URI.parse(url).host != @site_host
    rescue URI::InvalidURIError
      true
    end
  end

  def pagy_tailwind_nav(pagy)
    html = +'<nav class="flex justify-center gap-1" aria-label="Pagination">'

    # Common classes
    base_class = 'relative inline-flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors duration-200'
    inactive_class = "#{base_class} text-slate-500 hover:bg-slate-100 hover:text-slate-700 " \
                     'dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-200'
    active_class = "#{base_class} bg-indigo-600 text-white hover:bg-indigo-700 shadow-sm " \
                   'focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'
    disabled_class = "#{base_class} text-slate-300 dark:text-slate-600 cursor-not-allowed"

    # Prev
    html << if pagy.previous
              link_to('Prev', pagy.page_url(pagy.previous), class: inactive_class)
            else
              content_tag(:span, 'Prev', class: disabled_class)
            end

    # Series
    pagy.send(:series).each do |item|
      case item
      when Integer
        html << link_to(item, pagy.page_url(item), class: inactive_class)
      when String # current page
        html << content_tag(:span, item, class: active_class)
      when :gap
        html << content_tag(:span, '...', class: "#{base_class} text-slate-400 dark:text-slate-500")
      end
    end

    # Next
    html << if pagy.next
              link_to('Next', pagy.page_url(pagy.next), class: inactive_class)
            else
              content_tag(:span, 'Next', class: disabled_class)
            end

    html << '</nav>'
  end

  def logged_in?
    false
  end

  # <title> はHTML5仕様上RCDATA要素で、タグとして解釈されるのは "&" と "<" のみ。
  # content_for(:title, ...)にプレーン文字列を渡すとActionViewの内部バッファ格納時に
  # 一度HTMLエスケープされる（例: "'" → "&#39;"）ため、そのまま出力すると
  # デフォルトのHTMLエスケープ(h)で数値文字参照が二重化されたり、ブラウザ上は
  # 正しく表示されるとはいえソースに不要な参照が残ったりする。
  # 一度デコードして元の文字列に戻したうえで、<title>に必要な最小限（"&"と"<"）だけを
  # 再エスケープする。
  def page_title_text(text)
    CGI.unescapeHTML(text.to_s).gsub('&', '&amp;').gsub('<', '&lt;').html_safe
  end

  def markdown(text, sectionable: nil)
    return '' if text.blank?

    placeholders = {}
    text = expand_plugin_macros(text, sectionable:, placeholders:)

    renderer = ExternalAwareHtmlRenderer.new(site_host: request.host, hard_wrap: true)
    html = Redcarpet::Markdown.new(renderer,
                                   autolink: true,
                                   tables: true,
                                   fenced_code_blocks: true,
                                   strikethrough: true,
                                   no_intra_emphasis: true).render(text)
    restore_plugin_placeholders(html, placeholders).html_safe
  end

  private

  def external_url?(url)
    return false if url.blank? || url.start_with?('/', '#', 'mailto:')
    return true unless url.match?(%r{\Ahttps?://})

    URI.parse(url).host != request.host
  rescue URI::InvalidURIError
    true
  end

  # {{プラグイン名 パラメータ}} 形式の記法をディスパッチする
  PLUGIN_HANDLERS = {
    'include' => :expand_include_plugin,
    'snapshot' => :expand_snapshot_plugin,
    'item' => :expand_item_plugin,
    'div_begin' => :expand_div_begin_plugin,
    'div_end' => :expand_div_end_plugin
  }.freeze

  # パラメータ（{{プラグイン名 ...}} の "..." 部分）を省略した記法
  # （例: {{div_end}}）も許可するプラグイン
  PLUGINS_WITHOUT_REQUIRED_ARGS = %w[div_begin div_end].freeze

  def expand_plugin_macros(text, sectionable: nil, placeholders: {})
    # {{div_begin}}で開いたタグの種類（:div / :details）を対応する{{div_end}}まで
    # 覚えておくためのスタック。gsubはテキストを先頭から順に処理するため、
    # 通常のネストした記法であればこの単純なスタックで正しく対応付けられる。
    open_tags = []

    text.gsub(/\{\{(\w[\w-]*)(?:\s+(.+?))?\}\}/m) do
      plugin_name = Regexp.last_match(1)
      args = Regexp.last_match(2)&.strip
      handler = PLUGIN_HANDLERS[plugin_name]

      if handler && (args.present? || PLUGINS_WITHOUT_REQUIRED_ARGS.include?(plugin_name))
        send(handler, args, sectionable, placeholders, open_tags)
      else
        Regexp.last_match(0)
      end
    end
  end

  # レンダリング済みHTMLをMarkdown解析後に復元するためのプレースホルダーを発行する。
  # コンポーネントの生成するHTML（複数行タグ・Stimulus/htmx属性等）はRedcarpetの
  # 生HTMLブロック認識に乗らず壊れることがあるため、Markdown解析を経由させない。
  def register_plugin_placeholder(placeholders, html)
    token = "⟦PLUGIN_PLACEHOLDER_#{SecureRandom.hex(8)}⟧"
    placeholders[token] = html
    token
  end

  def restore_plugin_placeholders(html, placeholders)
    placeholders.each do |token, raw_html|
      html = html.sub("<p>#{token}</p>", raw_html)
      html = html.sub(token, raw_html)
    end
    html
  end

  # {{include key,セクション名}}       → CustomPage (key指定)
  # {{include unit:ID,セクション名}}   → Unit (ID指定)
  # {{include person:ID,セクション名}} → Person (ID指定)
  # {{include ,セクション名}}          → 自身のページ (key省略・カンマあり)
  # {{include セクション名}}           → 自身のページ (key省略・カンマなし)
  def expand_include_plugin(args, sectionable, _placeholders, _open_tags)
    identifier, section_name = args.include?(',') ? args.split(',', 2) : [nil, args]
    identifier = identifier&.strip
    section_name = section_name.strip

    owner = if identifier.nil? || identifier.empty?
              sectionable
            elsif identifier.start_with?('unit:')
              Unit.find_by(id: identifier.delete_prefix('unit:'))
            elsif identifier.start_with?('person:')
              Person.find_by(id: identifier.delete_prefix('person:'))
            else
              CustomPage.published.find_by(key: identifier)
            end

    section = owner&.sections&.kept&.find_by(name: section_name)
    section&.markdown.presence || section&.wiki_text.presence || ''
  end

  # {{snapshot ユニットkey,snapshot_id}}
  def expand_snapshot_plugin(args, _sectionable, placeholders, _open_tags)
    unit_key, snapshot_id = args.split(',', 2).map(&:strip)
    return '' if unit_key.blank? || snapshot_id.blank?

    unit = Unit.kept.find_by(key: unit_key)
    snapshot = unit&.unit_snapshots&.active&.find_by(id: snapshot_id)
    return '' unless snapshot

    html = render(UnitSnapshotsComponent.new(snapshots: [snapshot], unit: unit, admin: false, show_label: false)).to_s
    register_plugin_placeholder(placeholders, html)
  end

  # {{item ASIN}}
  def expand_item_plugin(args, _sectionable, placeholders, _open_tags)
    asin = args.strip
    return '' if asin.blank?

    item = Item.find_by(asin: asin)
    return '' unless item

    html = render(ItemCardComponent.new(item_card: item)).to_s
    register_plugin_placeholder(placeholders, html)
  end

  # HTML属性インジェクション対策のため、div_beginで出力できる属性は class / subject のみに限定する。
  # それ以外の記述（例: {{div_begin onclick="..."}}）は無視する。
  DIV_BEGIN_ALLOWED_ATTRS = %w[class subject].freeze

  # {{div_begin class="value"}}                     → <div class="value">
  # {{div_begin}}                                    → <div>
  # {{div_begin class="closable" subject="見出し"}} → 折りたたみ表示（初期状態は閉じている）。
  #   <details class="closable"><summary>見出し</summary> を出力し、
  #   ラベルのクリックで開閉する（class="closable" と subject の両方が揃った場合のみ）。
  #   開閉マーカーは<summary>のブラウザ標準表示に任せる。
  def expand_div_begin_plugin(args, _sectionable, placeholders, open_tags)
    attrs = parse_allowed_attrs(args, DIV_BEGIN_ALLOWED_ATTRS)
    class_value = attrs['class']
    subject_value = attrs['subject']

    html = if class_value == 'closable' && subject_value.present?
             open_tags.push(:details)
             "<details class=\"closable\"><summary>#{CGI.escapeHTML(subject_value)}</summary>"
           else
             open_tags.push(:div)
             class_value.present? ? %(<div class="#{CGI.escapeHTML(class_value)}">) : '<div>'
           end
    register_plugin_placeholder(placeholders, html)
  end

  # {{div_end}} → 対応する{{div_begin}}の種類に応じて </div> または </details> を出力する
  def expand_div_end_plugin(_args, _sectionable, placeholders, open_tags)
    html = open_tags.pop == :details ? '</details>' : '</div>'
    register_plugin_placeholder(placeholders, html)
  end

  # "key=\"value\"" または "key='value'" 形式の属性のうち allowed_names に含まれるものだけを抽出する
  def parse_allowed_attrs(args, allowed_names)
    attrs = {}
    args.to_s.scan(/(\w[\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')/) do |name, double_quoted, single_quoted|
      attrs[name] = double_quoted || single_quoted || '' if allowed_names.include?(name)
    end
    attrs
  end
end
