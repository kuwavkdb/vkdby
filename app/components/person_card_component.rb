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
    'group block bg-slate-50 dark:bg-slate-900/50 border border-slate-100 dark:border-slate-700 ' \
    'hover:border-person transition-all relative overflow-hidden p-4 rounded-lg'
  end

  def icon_padding_classes
    'p-2'
  end

  def icon_size_classes
    'w-10 h-10'
  end

  def name_classes
    'font-bold text-slate-800 dark:text-slate-200 group-hover:text-person transition-colors'
  end

  def kana_classes
    'text-xs text-slate-400 dark:text-slate-500 mt-0.5'
  end
end
