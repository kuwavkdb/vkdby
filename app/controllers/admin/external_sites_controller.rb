# frozen_string_literal: true

module Admin
  class ExternalSitesController < Admin::BaseController
    before_action :set_external_site, only: %i[edit update destroy]

    def index
      @pagy, @external_sites = pagy(ExternalSite.order(:site_key))
    end

    def new
      @external_site = ExternalSite.new
    end

    def edit; end

    def create
      @external_site = ExternalSite.new(external_site_params)

      if @external_site.save
        redirect_to admin_external_sites_path, notice: 'External site was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @external_site.update(external_site_params)
        redirect_to admin_external_sites_path, notice: 'External site was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @external_site.destroy
      redirect_to admin_external_sites_path, notice: 'External site was successfully destroyed.'
    end

    private

    def set_external_site
      @external_site = ExternalSite.find(params[:id])
    end

    def external_site_params
      params.require(:external_site).permit(:site_key, :url_pattern)
    end
  end
end
