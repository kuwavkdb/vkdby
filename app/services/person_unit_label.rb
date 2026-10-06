# frozen_string_literal: true

# 「今日は何の日？」の誕生日の投稿（OnThisDayPostBuilder、issue #1753）で人物名の後に付けるユニット名を求める。
# 在籍中なら "ユニット名"、在籍していなければ "ex-ユニット名"、付けない場合は nil を返す。
#
# 人物の経歴（Person#old_history）だけで判定する（メンバー表は見ない）。
# - 経歴に最後に書かれたユニット（最後の期間の項目）を付ける。最後の期間に複数ある（兼任など）場合は先に書かれたもの
# - その後に「→」があれば在籍していないとして ex- を付ける（どこにも在籍していない人は、経歴の末尾に「→」を付けて書く運用）
# - 経歴が空、またはユニット名を持つ項目がなければ付けない
# - サポートとしての在籍（役割か項目名に「サポート」を含む項目）は除く。最後の期間がサポートだけなら、
#   それより前の期間のユニットになり、後ろに「→」があるので ex- が付く（issue #1775）
class PersonUnitLabel
  EX_PREFIX = 'ex-'
  ARROW = '→'
  SUPPORT = 'サポート'
  # 表示名から除く <rt>（{{rb}}プラグインのルビ）
  RUBY_TEXT_PATTERN = %r{<rt>.*?</rt>}m

  def initialize(person)
    @person = person
  end

  def call
    timeline = @person.parse_old_history
    index = timeline.rindex { |group| group.any? { |item| candidate?(item) } }
    return nil unless index

    name = display_name(timeline[index].find { |item| candidate?(item) })
    # 後ろに別の期間（ステータスタグのみの期間など）があるか、経歴が「→」で終わっていれば在籍していない
    former = index < timeline.size - 1 || history_ends_with_arrow?
    former ? "#{EX_PREFIX}#{name}" : name
  end

  private

  # 付けるユニットの候補か（ユニット名があり、サポートとしての在籍ではない）
  def candidate?(item)
    display_name(item).present? && !support?(item)
  end

  def support?(item)
    item[:part_and_name].to_s.include?(SUPPORT) || item[:unit_name].to_s.include?(SUPPORT)
  end

  # parse_old_history は末尾の「→」を読み捨てるため、元のテキストで判定する（//で始まるコメント行は除く）
  def history_ends_with_arrow?
    @person.old_history.to_s.lines.reject { |line| line.strip.start_with?('//') }.join.strip.end_with?(ARROW)
  end

  # 経歴の表示名からタグ・ルビ・全体を囲む括弧を除く
  def display_name(item)
    name = ActionController::Base.helpers.strip_tags(item[:unit_name].to_s.gsub(RUBY_TEXT_PATTERN, '')).strip
    name = name[1..-2].strip if name.start_with?('(') && name.end_with?(')')
    CGI.unescapeHTML(name)
  end
end
