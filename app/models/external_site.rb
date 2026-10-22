# frozen_string_literal: true

# == Schema Information
#
# Table name: external_sites
#
#  id          :bigint           not null, primary key
#  name        :string
#  site_key    :string           not null
#  url_pattern :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_external_sites_on_site_key  (site_key) UNIQUE
#
class ExternalSite < ApplicationRecord
  validates :site_key, presence: true, uniqueness: true
  validates :url_pattern, presence: true
  validates :url_pattern, format: { with: /\A.*\{account\}.*\z/, message: 'must contain {account} placeholder' }

  # リンク欄のタイトル補完（link_title_suggest_controller.js）に渡す、表示名と URL パターンの一覧
  def self.link_title_suggestions
    where.not(name: [nil, '']).order(:site_key).map { |site| { name: site.name, url_pattern: site.url_pattern } }
  end
end
