# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    store_return_to(params[:return_to])
  end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      OperationLog.create!(user: user, operation_type: 'login')
      redirect_to session.delete(:return_to) || root_path, notice: 'ログインしました'
    else
      flash.now[:alert] = 'メールアドレスまたはパスワードが正しくありません'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    return_to = safe_return_to(params[:return_to])
    reset_session
    redirect_to return_to || root_path, notice: 'ログアウトしました'
  end
end
