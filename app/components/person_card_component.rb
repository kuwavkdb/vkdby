# frozen_string_literal: true

class PersonCardComponent < ViewComponent::Base
  with_collection_parameter :person
  def initialize(person:, show_history: false, show_details: false)
    super()
    @person = person
    @show_history = show_history
    @show_details = show_details
  end

  private

  def card_classes
    'group block bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 ' \
    'hover:border-person dark:hover:border-person hover:scale-[1.01] transition-all relative overflow-hidden p-4 rounded-lg'
  end

  def icon_padding_classes
    'p-2'
  end

  def icon_size_classes
    'w-10 h-10'
  end

  def name_classes
    'font-bold text-zinc-900 dark:text-zinc-100 group-hover:text-person transition-colors'
  end

  def kana_classes
    'text-xs text-zinc-500 dark:text-zinc-500 group-hover:text-person transition-colors'
  end
end
