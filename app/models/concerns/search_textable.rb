# frozen_string_literal: true

# 名前・ヨミガナ・名前の履歴（name_log）・別名（aliases）を SearchNormalizer で正規化して
# search_text 列に入れ、表記ゆれを吸収した部分一致検索をできるようにする（issue #1842）。
# search_text には trigram index を張っている。保存のたびに作り直すため、名前を変える処理は
# save を通すこと（update_all / update_column では作り直されない）。
# 正規化のルールを変えたときは `bundle exec rails search_text:rebuild` で作り直す。
module SearchTextable
  extend ActiveSupport::Concern

  included do
    before_save :assign_search_text

    # 名前系の列（search_text）の部分一致。query は空白で区切った語ごとの AND 検索にする。
    scope :matching_name, lambda { |query|
      SearchNormalizer.words(query).inject(all) { |relation, word| relation.where(name_match_condition(word)) }
    }
  end

  class_methods do
    # 1語ぶんの名前系の条件（Arel）。他の条件と組み合わせて使う。
    # 記号だけの語など、正規化すると空になる語は元の列（名前・ヨミガナ・名前の履歴・別名）を ILIKE で探す。
    # SQL 文字列への埋め込みを避けるため Arel で組み立てる（Brakeman 対策）
    def name_match_condition(word)
      normalized = SearchNormalizer.normalize(word)
      return arel_table[:search_text].matches("%#{sanitize_sql_like(normalized)}%", nil, true) if normalized.present?

      pattern = "%#{sanitize_sql_like(word)}%"
      columns = [arel_table[:name], arel_table[:name_kana]] +
                %i[name_log aliases].map { |c| Arel::Nodes::NamedFunction.new('CAST', [arel_table[c].as('text')]) }
      columns.map { |column| column.matches(pattern) }.reduce(:or)
    end

    # 全件の search_text を作り直す（正規化のルールを変えたとき・列を追加したときに使う）。
    # デプロイ時のマイグレーションでも使うため、1000件ずつまとめて1回の UPDATE（CASE 式）で書き込む
    def rebuild_search_text!
      unscoped.in_batches(of: 1000) do |batch|
        values = batch.each_with_object(Arel::Nodes::Case.new(arel_table[:id])) do |record, node|
          node.when(record.id).then(record.build_search_text)
        end
        batch.update_all(search_text: values)
      end
    end
  end

  def build_search_text
    entries = [self[:name], self[:name_kana]]
    Array(self[:name_log]).each do |entry|
      entry = entry.to_h.stringify_keys
      entries.push(entry['name'], entry['name_kana'])
    end
    Array(self[:aliases]).each do |entry|
      entry = entry.to_h.stringify_keys
      entries.push(entry['name'], entry['kana'])
    end
    SearchNormalizer.join(entries.map { |text| CGI.unescapeHTML(text.to_s) })
  end

  private

  def assign_search_text
    self.search_text = build_search_text
  end
end
