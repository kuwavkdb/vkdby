# frozen_string_literal: true

class AddMarkdownToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :markdown, :text
  end
end
