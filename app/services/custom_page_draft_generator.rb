# frozen_string_literal: true

# Issue#1086: page_type=custom_page に仕訳された Wikipage から、
# CustomPage (Markdown) の下書きをベストエフォートで生成する。
#
# 本番DBとローカルDBが分離しているため、このクラスはローカル環境でのみ使用し、
# 生成した下書きは人手で本番の管理画面へ貼り付けて仕上げる運用を想定している。
# （lib/tasks/custom_page_drafts.rake から呼び出す）
class CustomPageDraftGenerator
  Draft = Struct.new(:wikipage_id, :key, :title, :old_key, :body, :warnings, keyword_init: true)

  # CustomPage の markdown ヘルパー（ApplicationHelper#expand_plugin_macros）が
  # そのまま解釈できるプラグイン。変換せず残す。
  SUPPORTED_PLUGINS = %w[include snapshot item].freeze

  def self.generate(wikipage)
    new(wikipage).generate
  end

  def initialize(wikipage)
    @wikipage = wikipage
    @warnings = []
  end

  def generate
    body = @wikipage.wiki.to_s.dup
    body = strip_hidden_blocks(body)
    body = strip_comment_lines(body)
    body = convert_headings(body)
    body = convert_lists(body)
    body = convert_links(body)
    body = convert_horizontal_rules(body)
    body = convert_strikethrough(body)
    body = flag_unsupported_plugins(body)

    Draft.new(
      wikipage_id: @wikipage.id,
      key: "page-#{@wikipage.id}",
      title: @wikipage.title.presence || @wikipage.name,
      old_key: encoded_old_key,
      body: body.strip,
      warnings: @warnings
    )
  end

  private

  # {{b_hidden ...}} ブロックの除去（BaseWikipageImporter#preprocess_content と同様）
  def strip_hidden_blocks(text)
    text.gsub(/\{\{b_hidden.*?(?:^\}\}|\z)/m, '')
  end

  # // で始まるコメント行の除去
  def strip_comment_lines(text)
    text.lines.reject { |line| line.strip.start_with?('//') }.join
  end

  # PukiWiki記法では ! の数が多いほど上位の見出し（!!! が最大）。
  # !!! → #, !! → ##, ! → ### に変換する。
  def convert_headings(text)
    text.gsub(/^(!{1,3})(?!!)\s*(.*)$/) do
      level = 4 - Regexp.last_match(1).length
      ('#' * level) + " #{Regexp.last_match(2)}"
    end
  end

  # *** / ** / * の箇条書きをMarkdownの入れ子リストに変換
  def convert_lists(text)
    text.gsub(/^(\*{1,3})(?!\*)\s*(.*)$/) do
      depth = Regexp.last_match(1).length - 1
      ('  ' * depth) + "- #{Regexp.last_match(2)}"
    end
  end

  URL_LIKE = %r{\Ahttps?://|\A/}

  # [[label|target]]: target がURL（http(s)://・相対パス）ならMarkdownリンクに変換。
  #   それ以外（wikiページ名や TBTV-Visual:xxx のようなサービス記法）は自動変換できないため
  #   [[PageName]] と同様に unresolved 扱いにする。
  # [label|url]（シングルブラケット）は常にURLとして扱う（実データではURL/相対パスのみ）。
  # [[PageName]]（パイプなし）: Unit/Person を名前で解決できればプロフィールへのリンクにする。
  #   解決できなければ平文化し、要手動対応として警告に積む。
  def convert_links(text)
    text = text.gsub(/\[\[([^|\]]+)\|([^\]]+)\]\]/) do
      label = Regexp.last_match(1)
      target = Regexp.last_match(2)
      URL_LIKE.match?(target) ? "[#{label}](#{target})" : unresolved_link(label, "[[#{label}|#{target}]]")
    end
    text = text.gsub(/\[([^|\]]+)\|([^\]]+)\]/) { "[#{Regexp.last_match(1)}](#{Regexp.last_match(2)})" }
    text.gsub(/\[\[([^|\]]+)\]\]/) do
      label = Regexp.last_match(1)
      resolve_internal_link(label) || unresolved_link(label, "[[#{label}]]")
    end
  end

  # Unit/Person を完全一致の名前で検索し、見つかればプロフィールページへのMarkdownリンクを返す
  def resolve_internal_link(label)
    target = Unit.kept.find_by(name: label) || Person.kept.find_by(name: label)
    return nil unless target

    "[#{label}](/#{target.key})"
  end

  def unresolved_link(label, original_notation)
    @warnings << "内部リンク #{original_notation} はリンク解決できないため平文化しました（要手動対応）"
    label
  end

  def convert_horizontal_rules(text)
    text.gsub(/^-{4,}\s*$/, '---')
  end

  # ==打ち消し線== → ~~打ち消し線~~
  def convert_strikethrough(text)
    text.gsub(/==(.+?)==/) { "~~#{Regexp.last_match(1)}~~" }
  end

  # include / snapshot 以外のプラグイン記法はそのまま残すと崩れるため、
  # コメントで目印を付けて後で人手対応してもらう
  def flag_unsupported_plugins(text)
    text.gsub(/\{\{(\w[\w-]*)\s+.+?\}\}/m) do
      match = Regexp.last_match(0)
      plugin_name = Regexp.last_match(1)
      next match if SUPPORTED_PLUGINS.include?(plugin_name)

      @warnings << "未対応プラグイン #{plugin_name} を検出しました（要手動対応）"
      "<!-- TODO: 要手動対応 元記法: #{match} -->"
    end
  end

  def encoded_old_key
    URI.encode_www_form_component(@wikipage.name.to_s.encode('EUC-JP'))
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    @warnings << 'old_key の EUC-JP エンコードに失敗しました（要手動確認）'
    @wikipage.name.to_s
  end
end
