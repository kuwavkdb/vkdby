# frozen_string_literal: true

# == Schema Information
#
# Table name: person_logs
#
#  id               :bigint           not null, primary key
#  log_date         :string
#  log_type         :integer
#  name             :string
#  part             :integer
#  phenomenon       :integer          not null
#  phenomenon_alias :string
#  quote_text       :text
#  sort_order       :integer
#  source_url       :string
#  text             :text
#  unit_key         :string
#  unit_name        :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  person_id        :bigint           not null
#  unit_id          :bigint
#
# Indexes
#
#  index_person_logs_on_person_id                 (person_id)
#  index_person_logs_on_person_id_and_sort_order  (person_id,sort_order)
#  index_person_logs_on_unit_id                   (unit_id)
#
# Foreign Keys
#
#  fk_rails_...  (person_id => people.id)
#  fk_rails_...  (unit_id => units.id)
#
class PersonLog < ApplicationRecord
  belongs_to :person
  belongs_to :unit, optional: true

  enum :phenomenon,
       { original_member: 0, join: 1, leave: 2, pending: 3, rename: 4, convert: 5, stay: 6, retirement: 90, passed_away: 98, unknown: 99 }, prefix: true
  enum :part, { vocal: 0, guitar: 1, bass: 2, drums: 3, keyboard: 4, dj: 5, etc: 99 }

  validates :phenomenon, presence: true
  validates :log_date, format: { with: %r{\A\d{4}(/\d{2}(/\d{2})?)?\z} }, allow_blank: true

  PHENOMENON_TRANSLATIONS = {
    'original_member' => '初期メンバー',
    'join' => '加入',
    'leave' => '脱退',
    'pending' => '保留',
    'rename' => '改名',
    'convert' => 'コンバート',
    'stay' => '残留',
    'retirement' => '引退',
    'passed_away' => '死去',
    'unknown' => '不明'
  }.freeze

  def phenomenon_text
    phenomenon_alias.presence || PHENOMENON_TRANSLATIONS[phenomenon] || phenomenon&.humanize
  end

  def unit_name
    super.presence || unit&.name
  end

  def self.parse_wiki_text(text)
    return {} if text.blank?

    attributes = { quote_text: text }
    extract_date(text, attributes)
    extract_unit_and_part(text, attributes)
    extract_phenomenon(text, attributes)
    attributes
  end

  # Private class methods for parsing
  class << self
    private

    def extract_date(text, attributes)
      # Try {{fn YYYY/MM/DD}} format first
      if text =~ %r{\{\{fn\s+(\d{4}(?:/\d{1,2}(?:/\d{1,2})?)?)}
        attributes[:log_date] = ::Regexp.last_match(1)
      # Then try simple date format if found
      elsif text =~ %r{(\d{4}/\d{1,2}/\d{1,2})}
        attributes[:log_date] = ::Regexp.last_match(1)
      end
    end

    def extract_unit_and_part(text, attributes)
      part_text = extract_unit_name(text, attributes)
      extract_part_from_text(part_text || text, attributes, part_text)
    end

    def extract_unit_name(text, attributes)
      # Pattern 1: [[UnitName]](Part) or [[UnitName]]
      if text =~ /\[\[(.+?)\]\](?:\((.+?)\))?/
        attributes[:unit_name] = ::Regexp.last_match(1)
        return ::Regexp.last_match(2)
      end

      # Pattern 2: UnitName(Part) without brackets
      return unless text =~ /([^\s(]+)\(([^)]+)\)/

      potential_unit = ::Regexp.last_match(1)
      potential_part = ::Regexp.last_match(2)

      # Check if the part looks like a part name
      return unless part_like?(potential_part)

      attributes[:unit_name] = potential_unit
      potential_part
    end

    def part_like?(text)
      text =~ /vo\.?|gu\.?|gt\.?|ba\.?|dr\.?|key\.?|kb\.?|dj\.?|vocal|guitar|bass|drums|keyboard|ボーカル|ギター|ベース|ドラム|キーボード|[ぁ-ん]/i
    end

    def extract_part_from_text(part_source, attributes, part_text)
      return unless part_source.present?

      normalized = part_source.downcase.strip
      attributes[:part] = determine_part(normalized)

      # If part_text exists but doesn't match known parts, store as name
      attributes[:name] = part_text if part_text.present? && attributes[:part].nil?
    end

    def determine_part(normalized)
      case normalized
      when /\bvo\.?|vocal|ボーカル/i then 'vocal'
      when /\bgu\.?|gt\.?|guitar|ギター/i then 'guitar'
      when /\bba\.?|bass|ベース/i then 'bass'
      when /\bdr\.?|drums?|ドラム/i then 'drums'
      when /\bkey\.?|kb\.?|keyboard|キーボード/i then 'keyboard'
      when /\bdj\.?/i then 'dj'
      end
    end

    def extract_phenomenon(text, attributes)
      attributes[:phenomenon] = case text
                                when /脱退/ then :leave
                                when /加入/ then :join
                                when /結成/ then :original_member
                                when /解散/ then :leave
                                when /死去/ then :passed_away
                                when /引退/ then :retirement
                                when /サポート/ then :join
                                else :unknown
                                end
    end
  end
end
