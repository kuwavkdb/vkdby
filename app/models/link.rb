# frozen_string_literal: true

# == Schema Information
#
# Table name: links
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  linkable_type :string           not null
#  sort_order    :integer
#  text          :string
#  url           :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  linkable_id   :bigint           not null
#
# Indexes
#
#  index_links_on_linkable  (linkable_type,linkable_id)
#
class Link < ApplicationRecord
  belongs_to :linkable, polymorphic: true

  validates :url, presence: true

  def youtube_video_id
    return nil unless url.present?

    # Regular expression to extract YouTube video ID
    # Handles watch?v=, youtu.be/, embed/, etc.
    return unless url =~ %r{(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/)([^"&?/\s]{11})}

    ::Regexp.last_match(1)
  end

  def sns_info
    return nil unless url.present?

    case url
    when %r{twitter\.com/([^/?]+)}, %r{x\.com/([^/?]+)}
      { platform: 'Twitter', account: "@#{::Regexp.last_match(1)}" }
    when %r{instagram\.com/([^/?]+)}
      { platform: 'Instagram', account: ::Regexp.last_match(1) }
    when %r{youtube\.com/@([^/?]+)}, %r{youtube\.com/c/([^/?]+)}
      { platform: 'YouTube', account: ::Regexp.last_match(1) }
    end
  end

  def display_text
    base = text.presence || sns_info&.[](:platform) || url
    info = sns_info
    info ? "#{base} (#{info[:account]})" : base
  end
end
