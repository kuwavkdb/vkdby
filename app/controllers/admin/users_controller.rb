# frozen_string_literal: true

module Admin
  class UsersController < Admin::BaseController
    before_action :require_admin

    def index
      @users = User.all.order(created_at: :desc)
      @user = User.new # For the modal form
    end

    def create
      @user = User.new(user_params)
      temp_password = SecureRandom.hex(8)
      @user.password = temp_password

      if @user.save
        UserMailer.welcome_email(@user, temp_password).deliver_later
        redirect_to admin_users_path, notice: 'User created successfully. Email sent.'
      else
        @users = User.all.order(created_at: :desc)
        render :index, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.require(:user).permit(:name, :email, :role)
    end
  end
end
