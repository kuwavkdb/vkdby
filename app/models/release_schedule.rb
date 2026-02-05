# frozen_string_literal: true

# == Schema Information
#
# Table name: release_schedules
#
#  id            :bigint           not null, primary key
#  append_after  :text
#  append_before :text
#  artist        :string           default(""), not null
#  asin          :string
#  img_url       :string
#  l_img_url     :string
#  plugin_full   :text
#  plugin_text   :string           default(""), not null
#  product_group :string
#  publisher     :string
#  release_date  :datetime
#  title         :string
#  tracks        :text
#  type          :string           default(""), not null
#  url           :text
#  wiki          :string
#  created_at    :datetime
#  updated_at    :datetime
#  tower_id      :string
#
# Indexes
#
#  index_release_schedules_on_asin                   (asin)
#  index_release_schedules_on_plugin_text            (plugin_text) UNIQUE
#  index_release_schedules_on_wiki_and_release_date  (wiki,release_date)
#
class ReleaseSchedule < ApplicationRecord
  self.inheritance_column = :_type_disabled
end
