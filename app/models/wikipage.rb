# frozen_string_literal: true

# == Schema Information
#
# Table name: wikipages
#
#  id         :bigint           not null, primary key
#  category   :string
#  created_at :datetime         not null
#  dw_id      :integer
#  eplus_id   :integer
#  ip         :string(64)
#  it_id      :string(12)
#  level      :integer          default(0), not null
#  name       :string           not null
#  pia_id     :string(12)
#  title      :string(100)
#  updated_at :datetime         not null
#  wiki       :text
#
# Indexes
#
#  index_wikipages_on_name      (name) UNIQUE
#  index_wikipages_on_wiki_gin  (wiki) USING gin
#
class Wikipage < ApplicationRecord
end
