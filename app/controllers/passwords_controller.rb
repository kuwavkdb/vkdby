# frozen_string_literal: true

class PasswordsController < ApplicationController
  before_action :require_login

  def edit; end

  def update
    if current_user.authenticate(params[:current_password])
      if current_user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
        redirect_to root_path, notice: 'パスワードを変更しました'
      else
        flash.now[:alert] = 'パスワードの更新に失敗しました'
        render :edit, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = '現在のパスワードが正しくありません'
      render :edit, status: :unprocessable_entity
    end
  end
end
