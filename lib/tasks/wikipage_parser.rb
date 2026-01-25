# frozen_string_literal: true

# WikipageParser module provides common parsing utilities for Wikipage import scripts
module WikipageParser
  # LinkParser handles parsing and creating Link records from wiki content
  module LinkParser
    # Parse links from wiki content and create Link records
    # @param linkable [ActiveRecord::Base] Unit or Person model instance
    # @param content [String] Wiki content to parse
    # @param attributes [Hash] Additional attributes (dw_id, it_id, eplus_id)
    # @param active [Boolean] Whether links should be marked as active
    def self.parse_links(linkable, content, attributes = {}, active: true)
      return unless content

      # 1. [[Service:Account]] Format
      content.scan(/\[\[([^:]+):([^\]]+)\]\]/).each do |service, account|
        url = nil
        text = nil

        case service.downcase
        when 'twitter', 'x'
          url = "https://twitter.com/#{account}"
          text = 'Twitter'
        when 'youtube channel'
          url = "https://www.youtube.com/c/#{account}"
          text = 'YouTube Channel'
        when 'spotify'
          url = "https://open.spotify.com/artist/#{account}"
          text = 'Spotify'
        when 'vkgy'
          url = "https://vk.gy/artists/#{account}"
          text = 'vk.gy'
        when 'joysound'
          url = "https://www.joysound.com/web/search/artist/#{account}"
          text = 'JOYSOUND'
        when 'dam'
          url = "https://www.clubdam.com/app/leaf/artistKaraokeLeaf.html?artistCode=#{account}"
          text = 'DAM'
        when 'カラオケdam'
          url = "https://www.clubdam.com/karaokesearch/artistleaf.html?artistCode=#{account}"
          text = 'カラオケDAM'
        when 'digitlink'
          url = "https://www.digitlink.jp/#{account}"
          text = 'digitlink'
        when 'filmarks'
          url = "https://filmarks.com/users/#{account}"
          text = 'Filmarks'
        when 'ototoy'
          url = "https://ototoy.jp/_/default/a/#{account}"
          text = 'OTOTOY'
        when 'linkfire'
          url = "https://smr.lnk.to/#{account}"
          text = 'linkfire'
        when 'tiktok'
          url = "https://www.tiktok.com/@#{account}"
          text = 'TikTok'
        when 'linktr.ee'
          url = "https://linktr.ee/#{account}"
          text = 'linktr.ee'
        when 'lnk.to'
          url = "https://lnk.to/#{account}"
          text = 'lnk.to'
        end

        next unless url

        link = linkable.links.find_or_initialize_by(url: url)
        link.text = text
        link.active = active
        link.save!
      end

      # 2. [Label|URL] Format
      content.scan(/\[([^|\]]+)\|([^\]]+)\]/).each do |label, url|
        next unless url.start_with?('http')

        link = linkable.links.find_or_initialize_by(url: url)
        link.text = label
        link.active = active
        link.save!
      end

      # 3. {{outlink ...}} Format
      content.scan(/\{\{outlink\s+([^}]+)\}\}/).each do |match|
        type = match[0].strip
        url = nil
        text = nil

        case type
        when 'dw'
          if attributes['dw_id']
            url = "https://pc.dwango.jp/portals/artist/#{attributes['dw_id']}"
            text = 'ドワンゴジェイピー'
          end
        when 'it'
          if attributes['it_id']
            url = "https://music.apple.com/jp/artist/#{attributes['it_id']}"
            text = 'Apple Music'
          end
        when 'tunecore'
          text = 'TuneCore'
        end

        next unless url

        link = linkable.links.find_or_initialize_by(url: url)
        link.text = text
        link.active = active
        link.save!
      end
    end
  end

  # CategoryParser handles parsing category tags from wiki content
  module CategoryParser
    # Parse category tags from wiki content
    # @param content [String] Wiki content to parse
    # @return [Hash] Parsed categories
    def self.parse_categories(content)
      categories = {}

      # {{category 誕生日/MM/DD}}
      if content =~ %r{\{\{category 誕生日/(\d+)/(\d+)\}\}}
        categories[:birthday_month] = ::Regexp.last_match(1).to_i
        categories[:birthday_day] = ::Regexp.last_match(2).to_i
      end

      # {{category 誕生年/YYYY}} or {{category 誕生年/不明}}
      if content =~ %r{\{\{category 誕生年/(\d+)\}\}}
        categories[:birth_year] = ::Regexp.last_match(1).to_i
      elsif content =~ %r{\{\{category 誕生年/不明\}\}}
        categories[:birth_year_unknown] = true
      end

      # {{category 血液型/X}}
      if content =~ %r{\{\{category 血液型/([ABABO]+)\}\}}
        categories[:blood] = ::Regexp.last_match(1)
      elsif content =~ %r{\{\{category 血液型/不明\}\}}
        categories[:blood] = 'Unknown'
      end

      # {{category 出身地/XXX}}
      if content =~ %r{\{\{category 出身地/(.+?)\}\}}
        hometown = ::Regexp.last_match(1).strip
        categories[:hometown] = hometown unless hometown == '不明'
      end

      # Parts: {{category Bass}}, {{category Vocal}}, etc.
      categories[:parts] = []
      Person::AVAILABLE_PARTS.each do |part|
        categories[:parts] << part.downcase if content =~ /\{\{category #{part}\}\}/i
      end

      # Check if this is a person page
      categories[:is_person] = content =~ /\{\{category 個人/

      # Check for status categories
      categories[:is_retired] = content =~ /\{\{category 引退\}\}/
      categories[:is_free] = content =~ %r{\{\{category 個人/フリー\}\}}
      categories[:is_passed_away] = content =~ /\{\{category 死去\}\}/
      categories[:is_unknown] = content =~ %r{\{\{category 個人/状況不明\}\}}

      categories
    end
  end

  # Utils provides utility methods for encoding and key generation
  module Utils
    require 'romaji'

    # Encode string to EUC-JP URL format
    # @param str [String] String to encode
    # @return [String] URL-encoded EUC-JP string
    def self.encode_euc_jp_url(str)
      URI.encode_www_form_component(str.encode('EUC-JP'))
    end

    # Generate person key from name with optional birthday for uniqueness
    # @param wikipage_name [String] Original wikipage name
    # @param person_name [String] Person's name
    # @param person_name_kana [String] Person's name in kana (optional)
    # @param birthday_month [Integer] Birthday month (optional, for uniqueness)
    # @param birthday_day [Integer] Birthday day (optional, for uniqueness)
    # @return [String] URL-safe person key
    def self.generate_person_key(wikipage_name, person_name, person_name_kana = nil, birthday_month: nil,
                                 birthday_day: nil)
      source_for_key = wikipage_name

      if wikipage_name.match?(/^[[:ascii:]\s-]+$/)
        # Already ASCII
        source_for_key = wikipage_name
      elsif person_name_kana.present?
        # Convert Kana to Romaji
        source_for_key = Romaji.kana2romaji(person_name_kana)
      else
        # Try to convert name to romaji
        romaji_attempt = Romaji.kana2romaji(person_name)
        # If romanization failed (still contains non-ASCII), use encoded version
        source_for_key = if romaji_attempt.match?(/[^[:ascii:]]/)
                           # Use encoded old_key (without percent signs for readability)
                           encode_euc_jp_url(wikipage_name).gsub(/%/, '')
                         else
                           romaji_attempt
                         end
      end

      base_key = source_for_key.downcase.gsub(/\s+/, '-')

      # Append birthday suffix for uniqueness if available
      if birthday_month && birthday_day
        birthday_suffix = format('%02d%02d', birthday_month, birthday_day)
        "#{base_key}-#{birthday_suffix}"
      else
        base_key
      end
    end

    # Generate unit key from name
    # @param wikipage_name [String] Original wikipage name
    # @param unit_name_kana [String] Unit's name in kana (optional)
    # @return [String] URL-safe unit key
    def self.generate_unit_key(wikipage_name, unit_name_kana = nil)
      source_for_key = if wikipage_name.match?(/^[[:ascii:]\s-]+$/)
                         # Ascii only
                         wikipage_name
                       elsif unit_name_kana.present?
                         # Convert Kana to Romaji
                         Romaji.kana2romaji(unit_name_kana)
                       else
                         # Fallback to encoded old_key (without percent signs) to ensure ASCII
                         encode_euc_jp_url(wikipage_name).gsub(/%/, '')
                       end

      source_for_key.downcase.gsub(/\s+/, '-')
    end
  end
end
