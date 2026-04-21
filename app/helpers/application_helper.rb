# frozen_string_literal: true

module ApplicationHelper
  def pagy_tailwind_nav(pagy)
    html = +'<nav class="flex justify-center gap-1" aria-label="Pagination">'

    # Common classes
    base_class = 'relative inline-flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors duration-200'
    inactive_class = "#{base_class} text-slate-500 hover:bg-slate-100 hover:text-slate-700 " \
                     'dark:text-slate-400 dark:hover:bg-slate-800 dark:hover:text-slate-200'
    active_class = "#{base_class} bg-indigo-600 text-white hover:bg-indigo-700 shadow-sm " \
                   'focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'
    disabled_class = "#{base_class} text-slate-300 dark:text-slate-600 cursor-not-allowed"

    # Prev
    html << if pagy.previous
              link_to('Prev', pagy.page_url(pagy.previous), class: inactive_class)
            else
              content_tag(:span, 'Prev', class: disabled_class)
            end

    # Series
    pagy.send(:series).each do |item|
      case item
      when Integer
        html << link_to(item, pagy.page_url(item), class: inactive_class)
      when String # current page
        html << content_tag(:span, item, class: active_class)
      when :gap
        html << content_tag(:span, '...', class: "#{base_class} text-slate-400 dark:text-slate-500")
      end
    end

    # Next
    html << if pagy.next
              link_to('Next', pagy.page_url(pagy.next), class: inactive_class)
            else
              content_tag(:span, 'Next', class: disabled_class)
            end

    html << '</nav>'
  end

  def logged_in?
    false
  end

  def markdown(text, sectionable: nil)
    return '' if text.blank?

    text = expand_include_macros(text, sectionable:)

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: '_blank', rel: 'noopener noreferrer' }
    )
    Redcarpet::Markdown.new(renderer,
                            autolink: true,
                            tables: true,
                            fenced_code_blocks: true,
                            strikethrough: true,
                            no_intra_emphasis: true).render(text).html_safe
  end

  private

  # {{include key,セクション名}}       → CustomPage (key指定)
  # {{include unit:ID,セクション名}}   → Unit (ID指定)
  # {{include person:ID,セクション名}} → Person (ID指定)
  # {{include ,セクション名}}          → 自身のページ (key省略・カンマあり)
  # {{include セクション名}}           → 自身のページ (key省略・カンマなし)
  def expand_include_macros(text, sectionable: nil)
    text.gsub(/\{\{include\s+(?:([a-z0-9_:-]*),)?(.+?)\}\}/) do
      identifier = Regexp.last_match(1)&.strip
      section_name = Regexp.last_match(2).strip

      owner = if identifier.nil? || identifier.empty?
                sectionable
              elsif identifier.start_with?('unit:')
                Unit.find_by(id: identifier.delete_prefix('unit:'))
              elsif identifier.start_with?('person:')
                Person.find_by(id: identifier.delete_prefix('person:'))
              else
                CustomPage.published.find_by(key: identifier)
              end

      section = owner&.sections&.kept&.find_by(name: section_name)
      section&.markdown.presence || section&.wiki_text.presence || ''
    end
  end
end
