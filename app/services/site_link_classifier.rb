# frozen_string_literal: true

# リンク先がサイト内の相対パス／アンカー／mailto:かどうかを判定する共通ロジック。
# 通常のMarkdownレンダラー（ApplicationHelper::ExternalAwareHtmlRenderer、Section本文等）と
# 経歴専用パーサー（WikiParser、Person#old_history / UnitPerson・SnapshotPerson#inline_history）の
# 両方で、外部リンクアイコン・target="_blank"付与の要否判定に使う。
module SiteLinkClassifier
  module_function

  # "/xxx"（"//"始まりのプロトコル相対URLを除く）・"#xxx"・"mailto:xxx" は
  # 常にサイト内／安全なリンクとして扱う
  def relative_or_safe_link?(url)
    return false if url.blank?

    url.start_with?('/', '#', 'mailto:') && !url.start_with?('//')
  end
end
