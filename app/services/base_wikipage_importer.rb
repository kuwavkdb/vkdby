# frozen_string_literal: true

require 'romaji'

# Base class for Wikipage importers
# Provides common initialization, import flow, error handling, and link parsing
class BaseWikipageImporter
  include IgnorableWikipage

  attr_reader :original_content

  def self.import(wikipage)
    new(wikipage).import
  end

  def initialize(wikipage)
    @wikipage = wikipage
    @wiki_content = wikipage.wiki&.dup
    @original_content = @wiki_content&.dup
    @attributes = wikipage.attributes.slice('dw_id', 'it_id', 'eplus_id')
    @wikipage_name = wikipage.name
  end

  def import
    return if self.class.ignored?(@wikipage)
    return unless @wiki_content

    preprocess_content

    ActiveRecord::Base.transaction do
      process_import
    end
  rescue StandardError => e
    handle_error(e)
  end

  protected

  # Override in subclasses to implement specific import logic
  def process_import
    raise NotImplementedError, "#{self.class} must implement #process_import"
  end

  # Override in subclasses if custom preprocessing is needed
  def preprocess_content
    # Remove b_hidden blocks: {{b_hidden ... }} (ends with }} at the beginning of a line)
    @wiki_content = @wiki_content&.gsub(/\{\{b_hidden.*?(?:^\}\}|\z)/m, '')

    # Default: Remove comment lines
    @wiki_content = @wiki_content&.lines&.reject { |line| line.strip.start_with?('//') }&.join
  end

  def parse_youtube_tags(owner)
    return unless @wiki_content

    @wiki_content.scan(/\{\{youtube2\s+([^,|}]+)(?:,[^}]*)?\}\}/i) do |match|
      video_id = match[0].strip
      url = "https://youtu.be/#{video_id}"

      link = owner.links.find_or_initialize_by(url: url)
      link.text = 'YouTube Video' if link.text.blank?
      link.active = true
      link.save!
    end
  end

  def handle_error(error)
    puts "Error importing #{self.class.name.gsub('Importer', '')} #{@wikipage.id}: #{error.message}"
    puts error.backtrace.join("\n")
    raise error
  end

  # ==========================================
  # Shared Link Parsing Logic
  # ==========================================

  def parse_wiki_links(owner, content, active)
    return unless content

    # [[Text|Service:Account]] or [[Service:Account]] Format
    content.scan(/\[\[(?:([^|\]]+)\|)?([^:\]]+):([^\]]+)\]\]/).each do |text_part, site_key, account|
      service_name_down = site_key.downcase
      url = nil
      default_text = "#{site_key}:#{account}"

      # 1. Try ExternalSite (Database)
      external_site = ExternalSite.find_by(site_key: service_name_down)
      if external_site
        url = external_site.url_pattern.gsub('{account}', account)
      else
        # 2. Fallback to Hardcoded services
        url, mapped_text = map_service_link(service_name_down, account)
        default_text = mapped_text if url
      end

      next unless url

      link_text = text_part.presence || default_text

      link = owner.links.find_or_initialize_by(url: url)
      link.text = link_text
      link.active = active
      link.save!
    end

    # [Label|URL] Format
    content.scan(/\[([^|\]]+)\|([^\]]+)\]/).each do |label, url|
      next unless url.start_with?('http')

      link = owner.links.find_or_initialize_by(url: url)
      link.text = label
      link.active = active
      link.save!
    end

    # {{outlink ...}} Format
    content.scan(/\{\{outlink\s+([^}]+)\}\}/).each do |match|
      type = match[0].strip
      url, text = map_outlink(type)
      next unless url

      link = owner.links.find_or_initialize_by(url: url)
      link.text = text
      link.active = active
      link.save!
    end
  end

  def map_service_link(service, account)
    case service.downcase
    when 'twitter', 'x'
      ["https://twitter.com/#{account}", 'Twitter']
    when 'youtube channel'
      ["https://www.youtube.com/c/#{account}", 'YouTube Channel']
    when 'spotify'
      ["https://open.spotify.com/artist/#{account}", 'Spotify']
    when 'vkgy'
      ["https://vk.gy/artists/#{account}", 'vk.gy']
    when 'joysound'
      ["https://www.joysound.com/web/search/artist/#{account}", 'JOYSOUND']
    when 'dam'
      ["https://www.clubdam.com/app/leaf/artistKaraokeLeaf.html?artistCode=#{account}", 'DAM']
    when 'カラオケdam'
      ["https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=#{account}", 'カラオケDAM']
    when 'digitlink'
      ["https://www.digitlink.jp/#{account}", 'digitlink']
    when 'filmarks'
      ["https://filmarks.com/users/#{account}", 'Filmarks']
    when 'ototoy'
      ["https://ototoy.jp/_/default/a/#{account}", 'OTOTOY']
    when 'linkfire'
      ["https://smr.lnk.to/#{account}", 'linkfire']
    when 'tiktok'
      ["https://www.tiktok.com/@#{account}", 'TikTok']
    when 'linktr.ee'
      ["https://linktr.ee/#{account}", 'linktr.ee']
    when 'lnk.to'
      ["https://lnk.to/#{account}", 'lnk.to']
    end
  end

  def map_outlink(type)
    case type
    when 'dw'
      ["https://pc.dwango.jp/portals/artist/#{@attributes['dw_id']}", 'ドワンゴジェイピー'] if @attributes && @attributes['dw_id']
    when 'it'
      ["https://music.apple.com/jp/artist/#{@attributes['it_id']}", 'Apple Music'] if @attributes && @attributes['it_id']
    when 'tunecore'
      [nil, 'TuneCore']
    end
  end

  def extract_name_from_wiki_link(str)
    # Handle [[Display|Link]] or [[Link]]
    if str =~ /\[\[(?:([^|\]]+)\|)?([^\]]+)\]\]/
      str.gsub(/\[\[(?:([^|\]]+)\|)?([^\]]+)\]\]/) do
        Regexp.last_match(1) || Regexp.last_match(2)
      end
    else
      str
    end
  end

  # ==========================================
  # Section Parsing Logic
  # ==========================================

  # Issue#188: セクションの取り込み
  # 除外対象: リンク、メンバー*、関係者、個人情報、情報*、ディスコグラフィ*、経歴
  EXCLUDED_SECTIONS = %w[
    リンク
    メンバー
    関係者
    個人情報
    情報
    ディスコグラフィ
    経歴
    動向
    DVD
    関連記事
    関連商品
  ].freeze

  def parse_sections(owner)
    return unless @wiki_content

    # セクションを抽出: !!セクション名 から次の !! または文末まで
    # ^!!(?!!) で「!!」ちょうど2つで始まる行で分割
    # splitの結果: [preamble, name1, content1, name2, content2, ...]
    parts = @wiki_content.split(/^!!(?!!)(.*?)[\r\n]+/)
    parts.shift # 先頭の要素（最初のセクションより前のテキスト）は無視

    sections_data = []
    parts.each_slice(2) do |section_name, section_content|
      next if section_name.nil? || section_content.nil?

      sections_data << {
        name: section_name.strip,
        content: section_content.strip
      }
    end

    # 既存の Section レコードを削除
    owner.sections.destroy_all

    # 除外対象以外のセクションを保存
    sort_order = 1
    sections_data.each do |section_data|
      section_name = section_data[:name]
      section_content = section_data[:content]

      # 除外チェック: 完全一致またはワイルドカード（前方一致）
      is_excluded = EXCLUDED_SECTIONS.any? do |excluded|
        section_name == excluded || section_name.start_with?(excluded)
      end

      next if is_excluded

      # wiki_text が空の場合は除外
      next if section_content.blank?

      # 名前が空の場合は除外 (Fix: Name can't be blank error)
      next if section_name.blank?

      owner.sections.create!(
        name: section_name,
        wiki_text: section_content,
        sort_order: sort_order
      )
      sort_order += 1
    end
  end
end
