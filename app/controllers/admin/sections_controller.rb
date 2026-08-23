# frozen_string_literal: true

module Admin
  class SectionsController < Admin::BaseController
    before_action :set_section, only: %i[edit update destroy undiscard upload_image]
    before_action :set_sectionable
    before_action :require_admin, only: %i[upload_image]

    def new
      @section = @sectionable.sections.build
    end

    def edit; end

    def create
      @section = @sectionable.sections.build(section_params)
      if @section.save
        record_update_log(@section, action: 'create')
        redirect_to sectionable_edit_path, notice: 'セクションを追加しました。'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @section.update(section_params)
        record_update_log(@section, action: 'update')
        redirect_to sectionable_edit_path, notice: 'セクションを更新しました。'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @section.discard
      record_update_log(@section, action: 'discard')
      redirect_to sectionable_edit_path, notice: 'セクションを削除しました。'
    end

    def undiscard
      @section.undiscard
      record_update_log(@section, action: 'undiscard')
      redirect_to sectionable_edit_path, notice: 'セクションを復元しました。'
    end

    def upload_image
      image = params[:image]
      raise ActionController::BadRequest, 'Invalid file type' unless image&.content_type&.start_with?('image/')

      @section.images.attach(image)
      render json: { url: rails_blob_path(@section.images.last, disposition: :inline) }
    end

    def reorder
      params[:ids].each_with_index do |id, index|
        @sectionable.sections.find(id).update(sort_order: index + 1)
      end
      head :ok
    end

    # {{include}}/{{snapshot}}/{{item}} 等のプラグイン記法を含め、実際の公開ページと
    # 同じApplicationHelper#markdownでレンダリングしたHTMLを返す（issue #1193）。
    # sectionable_type/sectionable_idはフォームのhidden_field_tagから送られる
    # （set_sectionableが@sectionableを解決する）ため、{{include}}の
    # 「識別子省略＝自分自身」記法も編集中の内容でプレビューできる。
    def preview
      render json: { html: helpers.markdown(params[:body].to_s, sectionable: @sectionable) }
    end

    private

    def set_sectionable
      if @section
        @sectionable = @section.sectionable
      else
        type = params[:sectionable_type]
        id   = params[:sectionable_id]
        @sectionable = case type
                       when 'Unit'       then Unit.find(id)
                       when 'Person'     then Person.find(id)
                       when 'CustomPage' then CustomPage.with_discarded.find(id)
                       else raise ActionController::BadRequest, 'Invalid sectionable_type'
                       end
      end
    end

    def set_section
      @section = Section.with_discarded.find(params[:id])
    end

    def sectionable_edit_path
      case @sectionable
      when Unit       then edit_admin_unit_path(@sectionable)
      when Person     then edit_admin_person_path(@sectionable)
      when CustomPage then edit_admin_custom_page_path(@sectionable)
      end
    end

    def section_params
      params.require(:section).permit(:name, :wiki_text, :markdown, :sort_order, :active)
    end
  end
end
