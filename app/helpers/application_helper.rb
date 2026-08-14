# frozen_string_literal: true

require 'cgi'
require 'digest'

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
    'div_end' => :expand_div_end_plugin,
    'member' => :expand_member_plugin,
    'member2' => :expand_member2_plugin
  }.freeze

  # パラメータ（{{プラグイン名 ...}} の "..." 部分）を省略した記法
  # （例: {{div_end}}）も許可するプラグイン
  PLUGINS_WITHOUT_REQUIRED_ARGS = %w[div_begin div_end].freeze

  # コンポーネントレンダリングを伴うプラグインのキャッシュ設定（plugin_cache_fetch参照）
  PLUGIN_CACHE_VERSION = 'v1'
  PLUGIN_CACHE_TTL = 7.days

  # 複数行にわたるプラグイン記法（例: {{member2 ...}}）のディスパッチ先。
  # 1行目に閉じの"}}"がなければ複数行プラグインとみなし、次に現れる
  # "}}"のみの行までをdataとして扱う（本文中に{{fn ...}}のような単行プラグインが
  # ネストしていても、それ単体では終端と誤認しない）。
  MULTILINE_PLUGIN_HANDLERS = {
    'member2' => :expand_member2_plugin
  }.freeze

  def expand_plugin_macros(text, sectionable: nil, placeholders: {})
    text = expand_multiline_plugin_macros(text, sectionable, placeholders)

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

  # {{プラグイン名 1行目のパラメータ\n複数行のdata\n}}
  # 1行目末尾に"}}"がない（=閉じていない）場合のみ複数行プラグインとして扱う。
  # 終端は単独で"}}"だけの行。
  def expand_multiline_plugin_macros(text, sectionable, placeholders)
    names = Regexp.union(MULTILINE_PLUGIN_HANDLERS.keys)

    text.gsub(/\{\{(#{names})(?:[ \t]+([^\n]*))?\n(.*?)\n[ \t]*\}\}[ \t]*$/m) do
      plugin_name = Regexp.last_match(1)
      args = Regexp.last_match(2)&.strip
      data = Regexp.last_match(3)
      handler = MULTILINE_PLUGIN_HANDLERS[plugin_name]

      send(handler, args, sectionable, placeholders, [], data)
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

  # {{item}} / {{member}} / {{member2}} / {{snapshot}} はコンポーネントのレンダリングを
  # 伴いコストが高いため、結果のHTML断片をRails.cacheに保存して再利用する（issue #1115）。
  # key_partsには参照先レコードの cache_key_with_version（id + updated_at）を含めることで、
  # レコードが更新されるたびにキーが変わり、明示的な無効化なしに自動でキャッシュが切り替わる。
  # expires_in は更新のないレコードのキャッシュがRedis上に無期限に残り続けないための保険。
  def plugin_cache_fetch(*key_parts, &)
    key = (['markdown_plugin', PLUGIN_CACHE_VERSION] + key_parts).join('/')
    Rails.cache.fetch(key, expires_in: PLUGIN_CACHE_TTL, &)
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

    html = plugin_cache_fetch('snapshot', unit.cache_key_with_version, snapshot.cache_key_with_version) do
      render(UnitSnapshotsComponent.new(snapshots: [snapshot], unit: unit, admin: false, show_label: false)).to_s
    end
    register_plugin_placeholder(placeholders, html)
  end

  # {{item ASIN}}
  def expand_item_plugin(args, _sectionable, placeholders, _open_tags)
    asin = args.strip
    return '' if asin.blank?

    item = Item.find_by(asin: asin)
    return '' unless item

    html = plugin_cache_fetch('item', item.cache_key_with_version) do
      render(ItemCardComponent.new(item_card: item)).to_s
    end
    register_plugin_placeholder(placeholders, html)
  end

  # {{member パート,表示名,old_key,リンク}}（old_keyは未エンコード。リンクは省略可）
  # リンクはURL（http(s)://…）またはXアカウント（@xxxx）を指定する
  # （MemberRowComponentが@始まりをXアカウントとして自動判定しX(Twitter)へのリンクを表示する）。
  # 例: {{member Vocal,のる,のる(ex-ふりぃ),@noru_xxx}}
  # old_keyをEUC-JPエンコードしてPeopleを検索し、Unitページのメンバー行
  # （MemberRowComponent）と同じ経歴カードを出力する。
  def expand_member_plugin(args, _sectionable, placeholders, _open_tags)
    part, display_name, raw_old_key, link = args.split(',', 4).map { |v| v&.strip }
    return '' if part.blank? || display_name.blank? || raw_old_key.blank?

    person = Person.kept.find_by(old_key: encode_member_old_key(raw_old_key))
    return '' unless person

    html = plugin_cache_fetch('member', person.cache_key_with_version, Digest::MD5.hexdigest(args)) do
      member = MemberPluginRow.new(part: part, name: display_name, person: person, sns: link.presence && [link])
      render(MemberRowComponent.new(member: member, hide_status: true)).to_s
    end
    register_plugin_placeholder(placeholders, html)
  end

  # People#old_key は URI.encode_www_form_component(EUC-JP) 形式で保存されている
  # （app/services/person_importer.rb, wikipage_importer.rb と同じ変換）
  def encode_member_old_key(text)
    URI.encode_www_form_component(text.encode('EUC-JP'))
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    text
  end

  # {{member}}プラグイン用の軽量な行データ。UnitPerson/SnapshotPersonと異なりDBに
  # 永続化しない埋め込み表示のためのラッパーで、MemberRowComponentが要求する
  # インターフェース（part / name / person / part_alias / sns / inline_history / status / support?）
  # のうち、プラグインが受け取らない属性はすべて未指定（nil・非サポート）として扱う。
  # inline_historyはmember2（old_key不一致時）でのみ使用し、parse_inline_historyで
  # UnitPerson同様WikiParser#parse_history_stringに委譲する。
  MemberPluginRow = Struct.new(:part, :name, :person, :part_alias, :sns, :inline_history, :status, keyword_init: true) do
    include WikiParser

    def support?
      false
    end

    def parse_inline_history
      parse_history_string(inline_history)
    end
  end

  # {{member2 パート,表示名,old_key,リンク\nメンバー経歴\n}}
  # （old_key・リンクは未エンコード・省略可。old_keyは"-"でも未指定扱い）
  # リンクはURL（http(s)://…）またはXアカウント（@xxxx）を指定する（member参照）。
  # 例:
  #   {{member2 Bass,森川泰敬
  #   → [GLAMOROUS HONEY](/glamorous-honey){{fn 2006/05/10加入}}
  #   }}
  # old_keyが一致するPersonが見つかればmemberプラグインと同様にそのPersonの経歴を出力する。
  # 一致しない（またはold_key省略・"-"指定）場合は、ブロック内のdata（1行目以降）を
  # そのメンバー自身の経歴として扱い、経歴カードを出力する（[Label](URL)形式のリンクや
  # {{fn ...}}のような注記プラグインを含められる。WikiParser#parse_history_string参照）。
  # リンクはold_keyの一致有無にかかわらず指定があれば表示する。
  # 単独行（{{member2 パート,表示名,old_key}}）で使った場合はdataなしのmemberプラグイン相当になる。
  def expand_member2_plugin(args, _sectionable, placeholders, _open_tags, data = nil)
    part, display_name, raw_old_key, link = args.to_s.split(',', 4).map { |v| v&.strip }
    return '' if part.blank? || display_name.blank?

    raw_old_key = nil if raw_old_key.blank? || raw_old_key == '-'
    person = raw_old_key && Person.kept.find_by(old_key: encode_member_old_key(raw_old_key))

    # personが見つかった場合dataは経歴として使われない（下記inline_history参照）ため、
    # その場合はキャッシュキーからdataを除外しヒット率を上げる。
    fingerprint = person ? args.to_s : "#{args}\n#{data}"
    person_key = person&.cache_key_with_version || 'noperson'

    html = plugin_cache_fetch('member2', person_key, Digest::MD5.hexdigest(fingerprint)) do
      member = MemberPluginRow.new(
        part: part,
        name: display_name,
        person: person,
        sns: link.presence && [link],
        inline_history: person ? nil : data.to_s.strip.presence
      )
      render(MemberRowComponent.new(member: member, hide_status: true)).to_s
    end
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
