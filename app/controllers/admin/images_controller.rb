# frozen_string_literal: true

module Admin
  class ImagesController < Admin::BaseController
    ATTACHABLE_TYPES = %w[Section CustomPage].freeze

    before_action :require_admin

    def index
      scope = ActiveStorage::Attachment
              .includes(:blob, :record)
              .where(record_type: ATTACHABLE_TYPES, name: 'images')
              .order(created_at: :desc)

      if params[:q].present?
        blob_ids = ActiveStorage::Blob.where('filename ILIKE ?', "%#{params[:q]}%").pluck(:id)
        scope = scope.where(blob_id: blob_ids)
      end

      @pagy, @attachments = pagy(scope)
    end

    def show
      @attachment = ActiveStorage::Attachment
                    .includes(:blob, record: :sectionable)
                    .where(record_type: ATTACHABLE_TYPES, name: 'images')
                    .find(params[:id])
      @image_url = url_for(@attachment)

      # ファイル名でMarkdownコンテンツを検索し、参照している可能性のある箇所を探す
      filename = @attachment.blob.filename.to_s
      @referencing_sections = Section.includes(:sectionable).where('markdown ILIKE :q OR wiki_text ILIKE :q', q: "%#{filename}%")
      @referencing_custom_pages = CustomPage.with_discarded.where('body ILIKE ?', "%#{filename}%")
    end

    def destroy
      attachment = ActiveStorage::Attachment
                   .where(record_type: ATTACHABLE_TYPES, name: 'images')
                   .find(params[:id])
      attachment.purge
      redirect_to admin_images_path(q: params[:q]), notice: '画像を削除しました。'
    end
  end
end
