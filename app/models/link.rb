# == Schema Information
#
# Table name: links
#
#  id            :bigint           not null, primary key
#  active        :boolean          default(TRUE)
#  linkable_type :string(255)      not null
#  sort_order    :integer
#  text          :string(255)
#  url           :string(255)      not null
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
    if url =~ /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/
      $1
    end
  end

  def sns_info
    return nil unless url.present?
    case url
    when /twitter\.com\/([^\/\?]+)/, /x\.com\/([^\/\?]+)/
      { platform: "Twitter", account: "@#{$1}" }
    when /instagram\.com\/([^\/\?]+)/
      { platform: "Instagram", account: $1 }
    when /youtube\.com\/@([^\/\?]+)/, /youtube\.com\/c\/([^\/\?]+)/
      { platform: "YouTube", account: $1 }
    else
      nil
    end
  end

  def display_text
    base = text.presence || sns_info&.[](:platform) || url
    info = sns_info
    info ? "#{base} (#{info[:account]})" : base
  end
end
