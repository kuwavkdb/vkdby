# frozen_string_literal: true

class UpdateLog < ApplicationRecord
  belongs_to :user
  belongs_to :loggable, polymorphic: true, optional: true
  # 実際に編集されたレコード(loggable)とは別に、その編集をどのページの更新として
  # 扱うかを表す。Unit/Person/CustomPage自身の編集ではloggableと同じレコードを指すが、
  # Link/Section/UnitSnapshot/SnapshotPersonのようなネストしたレコードの編集では、
  # 書き込み時に親ページ（Unit/Person/CustomPage）を指すよう明示的に渡す。
  belongs_to :subject, polymorphic: true, optional: true

  # サイドバー「最近の更新」に集計対象として含めるsubjectの型・アクション。
  # 対象を各ページ自身のcreate/updateのみに絞り、discard/undiscard/change_key/purgeや
  # Unit/Person/CustomPage以外のsubjectは含めない（issue #1530）。
  SIDEBAR_SUBJECT_TYPES = %w[Unit Person CustomPage].freeze
  SIDEBAR_ACTIONS = %w[create update].freeze

  scope :for_sidebar, -> { where(subject_type: SIDEBAR_SUBJECT_TYPES, action: SIDEBAR_ACTIONS).order(created_at: :desc) }

  def loggable
    case loggable_type
    when 'Section'
      Section.with_discarded.find_by(id: loggable_id)
    when 'SnapshotPerson'
      SnapshotPerson.with_discarded.find_by(id: loggable_id)
    when 'CustomPage'
      CustomPage.with_discarded.find_by(id: loggable_id)
    else
      super
    end
  end

  validates :action, inclusion: { in: %w[create update discard undiscard change_key purge] }

  def self.for_unit(unit)
    snapshot_ids = unit.unit_snapshot_ids
    snapshot_person_ids = SnapshotPerson.with_discarded.where(unit_snapshot_id: snapshot_ids).pluck(:id)
    link_ids = unit.links.pluck(:id)
    section_ids = Section.with_discarded.where(sectionable_type: 'Unit', sectionable_id: unit.id).pluck(:id)

    where(loggable_type: 'Unit', loggable_id: unit.id)
      .or(where(loggable_type: 'UnitSnapshot', loggable_id: snapshot_ids))
      .or(where(loggable_type: 'SnapshotPerson', loggable_id: snapshot_person_ids))
      .or(where(loggable_type: 'Link', loggable_id: link_ids))
      .or(where(loggable_type: 'Section', loggable_id: section_ids))
  end

  def self.for_venue(venue)
    link_ids = venue.links.pluck(:id)

    where(loggable_type: 'Venue', loggable_id: venue.id)
      .or(where(loggable_type: 'Link', loggable_id: link_ids))
  end

  def self.for_person(person)
    link_ids = person.links.pluck(:id)
    section_ids = Section.with_discarded.where(sectionable_type: 'Person', sectionable_id: person.id).pluck(:id)

    where(loggable_type: 'Person', loggable_id: person.id)
      .or(where(loggable_type: 'Link', loggable_id: link_ids))
      .or(where(loggable_type: 'Section', loggable_id: section_ids))
  end
end
