# frozen_string_literal: true

# Issue#1086: page_type=custom_page に仕訳された Wikipage から、
# CustomPage (Markdown) の下書きをベストエフォートで生成する。
#
# 本番DBとローカルDBが分離しているため、このクラスはローカル環境でのみ使用し、
# 生成した下書きは人手で本番の管理画面へ貼り付けて仕上げる運用を想定している。
# （lib/tasks/custom_page_drafts.rake から呼び出す）
class CustomPageDraftGenerator
  Draft = Struct.new(:wikipage_id, :key, :title, :old_key, :body, :warnings, keyword_init: true)

  # 変換せずそのまま残すプラグイン。
  # snapshot / item / div_begin は CustomPage の markdown ヘルパー
  # （ApplicationHelper#expand_plugin_macros）がそのまま解釈できる（Issue#1105でdiv_begin/div_end対応）。
  # div / member は現時点では未対応だが、CustomPage側での対応を予定しているため、
  # TODOコメント化せず元の記法のまま残す。
  # include は旧FreeStyleWiki記法と引数の意味が異なる（IncludePluginConverter参照）ため対象外。
  SUPPORTED_PLUGINS = %w[snapshot item div_begin div member].freeze

  # 旧FreeStyleWikiの {{include ページ名,セクション名}} は「他ページの内容をページ名で
  # 丸ごと埋め込む」記法だが、新CustomPageの {{include}} マクロ
  # （ApplicationHelper#expand_include_plugin）は
  # {{include unit:ID,セクション名}} / {{include person:ID,セクション名}} で
  # 実在する Section を差し込む用途に変わっており意味が異なる。
  # プラグイン名が一致するだけで素通りさせると、変換先が見つからず警告なしに
  # 本文が消えてしまう（Issue#1106）ため、実際に差し込み先の Section まで
  # 解決できた場合のみ新形式に変換し、できなければ要手動対応の警告を積む。
  class IncludePluginConverter
    def initialize(warnings)
      @warnings = warnings
    end

    def convert(match, args)
      identifier, section_name = args.include?(',') ? args.split(',', 2) : [nil, args]
      identifier = identifier&.strip
      section_name = section_name&.strip

      return unsupported(match, 'カンマなし(自己参照形式)は変換できません') if identifier.blank?

      target = resolve_target(identifier)
      return unsupported(match, "参照先 #{identifier.inspect} を解決できません") unless target

      section = target.sections.kept.find_by(name: section_name)
      return unsupported(match, "#{target.class.name}##{target.id} にセクション「#{section_name}」が見つかりません") unless section

      "{{include #{identifier_for(target)},#{section_name}}}"
    end

    private

    # ・unit:ID / person:ID: 新形式そのまま
    # ・それ以外: 旧FreeStyleWikiのページ名指定とみなし、WikiPageImportの仕訳結果から辿る
    def resolve_target(identifier)
      if identifier.start_with?('unit:')
        Unit.kept.find_by(id: identifier.delete_prefix('unit:'))
      elsif identifier.start_with?('person:')
        Person.kept.find_by(id: identifier.delete_prefix('person:'))
      else
        resolve_target_by_page_name(identifier)
      end
    end

    def resolve_target_by_page_name(page_name)
      wikipage = Wikipage.find_by(name: page_name)
      wpi = wikipage && WikiPageImport.find_by(wikipage_id: wikipage.id, status: 'imported')

      case wpi&.import_target_type
      when 'Unit' then Unit.kept.find_by(id: wpi.import_target_id)
      when 'Person' then Person.kept.find_by(id: wpi.import_target_id)
      end
    end

    def identifier_for(target)
      target.is_a?(Unit) ? "unit:#{target.id}" : "person:#{target.id}"
    end

    def unsupported(match, reason)
      @warnings << "未対応プラグイン include を検出しました（#{reason}／要手動対応）"
      "<!-- TODO: 要手動対応 元記法: #{match} -->"
    end
  end

  def self.generate(wikipage)
    new(wikipage).generate
  end

  def initialize(wikipage)
    @wikipage = wikipage
    @warnings = []
    @include_converter = IncludePluginConverter.new(@warnings)
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
    body = normalize_blank_lines(body)

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

  # FreeStyleWiki記法では ! の数が多いほど上位の見出し（!!! が最大）。
  # !!! → #, !! → ##, ! → ### に変換する。
  # 直前が箇条書き等の場合、空行を挟まないとMarkdown上でリスト項目の続きとして
  # 解釈されてしまう（見出しとして認識されない）ため、見出しの前に必ず空行を入れる。
  # 連続見出し等で空行が重複した場合は normalize_blank_lines で正規化する。
  def convert_headings(text)
    text.gsub(/^(!{1,3})(?!!)\s*(.*)$/) do
      level = 4 - Regexp.last_match(1).length
      "\n#{'#' * level} #{Regexp.last_match(2)}"
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

  # include / snapshot / item 以外のプラグイン記法はそのまま残すと崩れるため、
  # コメントで目印を付けて後で人手対応してもらう。include は個別に検証する
  # （IncludePluginConverter参照）ため、ここでは判定対象から除く。
  def flag_unsupported_plugins(text)
    text.gsub(/\{\{(\w[\w-]*)\s+(.+?)\}\}/m) do
      match = Regexp.last_match(0)
      plugin_name = Regexp.last_match(1)
      args = Regexp.last_match(2)

      next @include_converter.convert(match, args) if plugin_name == 'include'
      next match if SUPPORTED_PLUGINS.include?(plugin_name)

      @warnings << "未対応プラグイン #{plugin_name} を検出しました（要手動対応）"
      "<!-- TODO: 要手動対応 元記法: #{match} -->"
    end
  end

  # convert_headings で挿入した空行により3行以上の連続改行ができた場合、空行1つに正規化する
  def normalize_blank_lines(text)
    text.gsub(/\n{3,}/, "\n\n")
  end

  def encoded_old_key
    URI.encode_www_form_component(@wikipage.name.to_s.encode('EUC-JP'))
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    @warnings << 'old_key の EUC-JP エンコードに失敗しました（要手動確認）'
    @wikipage.name.to_s
  end
end
