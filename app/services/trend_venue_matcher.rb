# frozen_string_literal: true

# 既存Trendのタイトルの括弧書き・本文の[[会場名]]から会場名を取り出し、Venueと突き合わせる（issue #1690）。
# 突き合わせは name / aliases / name_log の名前と、旧Wikiページ名（old_keyを戻したもの）の完全一致のみ。
#
# 会場の書き方の慣習は「タイトル末尾の半角括弧」なので、次の順に探して最初に見つかったものを採る。
# 1. タイトル末尾の括弧
# 2. タイトル中の括弧（`解散([[高田馬場AREA]]) → 延期` のように括弧の後ろに続きがあるもの）
# 3. 括弧の外・本文のWikiリンク。本文の2行目以降は「加入後の初ライブは11/08([[池袋BlackHole]])」のように
#    Trend自体とは別の公演の会場であることが多いため、自動では紐付けず要確認（:review）にとどめる。
#    本文のWikiリンクには人名・ユニット名も含まれるので、会場に一致した名前だけを拾う。
class TrendVenueMatcher
  # status: :matched（候補1件）/ :ambiguous（候補複数）/ :review（括弧外・本文でのみ見つかった）
  #         / :unmatched（末尾の括弧はあるが一致なし）/ :none（会場名なし）
  # source: :title_trailing / :title_parenthetical / :content
  Result = Data.define(:status, :source, :names, :venue_ids)

  WIKI_LINK_PATTERN = /\[\[([^\[\]]+)\]\]/
  # 生のタイトル中の半角括弧。括弧の中に [[表示|リンク先]] があってもよい
  RAW_PARENTHETICAL = /\(((?:\[\[[^\[\]]*\]\]|[^()\[\]])*)\)/
  PLAIN_PARENTHETICAL = /\(([^()]*)\)/

  def initialize(venues = Venue.kept)
    @index = build_index(venues)
  end

  def match(trend)
    trailing = trailing_names(trend)
    ids = lookup(trailing)
    return result(:title_trailing, trailing, ids) if ids.any?

    names = venue_names_only(parenthetical_names(trend))
    ids = lookup(names)
    return result(:title_parenthetical, names, ids) if ids.any?

    names = venue_names_only(link_parts("#{trend.title}\n#{trend.content}"))
    ids = lookup(names)
    return Result.new(status: :review, source: :content, names:, venue_ids: ids) if ids.any?

    Result.new(status: trailing.any? ? :unmatched : :none, source: :title_trailing, names: trailing, venue_ids: [])
  end

  private

  def result(source, names, venue_ids)
    Result.new(status: venue_ids.one? ? :matched : :ambiguous, source:, names:, venue_ids:)
  end

  def lookup(names)
    names.flat_map { |name| @index.fetch(name, []) }.uniq
  end

  def venue_names_only(names)
    names.select { |name| @index.key?(name) }
  end

  def trailing_names(trend)
    names = []
    plain = trend.title_as_plain_text.match(/#{PLAIN_PARENTHETICAL}\z/o)
    names << plain[1] if plain
    raw = trend.title.to_s.match(/#{RAW_PARENTHETICAL}\z/o)
    names.concat(link_parts(raw[1])) if raw
    normalize(names)
  end

  def parenthetical_names(trend)
    names = trend.title_as_plain_text.scan(PLAIN_PARENTHETICAL).flatten
    trend.title.to_s.scan(RAW_PARENTHETICAL).flatten.each { |group| names.concat(link_parts(group)) }
    normalize(names)
  end

  # [[表示|リンク先]] は表示・リンク先のどちらも候補にする
  def link_parts(text)
    normalize(text.scan(WIKI_LINK_PATTERN).flatten.flat_map { |link| link.split('|') })
  end

  def normalize(names)
    names.map(&:strip).reject(&:blank?).uniq
  end

  def build_index(venues)
    index = Hash.new { |hash, key| hash[key] = [] }
    venues.find_each do |venue|
      venue_names(venue).each { |name| index[name] << venue.id }
    end
    index.transform_values(&:uniq)
  end

  def venue_names(venue)
    names = [venue.name, old_page_name(venue.old_key)]
    names.concat((venue[:aliases] || []).map { |entry| entry['name'] })
    names.concat((venue.name_log || []).map { |entry| entry['name'] })
    normalize(names.compact)
  end

  # old_keyは旧WikiページのページネームをEUC-JPでURLエンコードしたもの（LegacyRedirectsController#decode_euc_jpと同じ変換）
  def old_page_name(old_key)
    return nil if old_key.blank?

    URI.decode_www_form_component(old_key).force_encoding('EUC-JP').encode('UTF-8')
  rescue StandardError
    nil
  end
end
