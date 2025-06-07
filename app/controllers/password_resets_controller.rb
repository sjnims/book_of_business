# Handles password reset functionality for users who have forgotten their password
#
# The password reset flow:
# 1. User requests reset by providing email (new/create actions)
# 2. System generates secure token and would send email with reset link
# 3. User clicks link to access reset form (edit action)
# 4. User submits new password (update action)
# 5. Token is cleared after successful reset
#
# Tokens expire after 2 hours for security
class PasswordResetsController < ApplicationController
  before_action :get_user, only: [ :edit, :update ]
  before_action :valid_user, only: [ :edit, :update ]
  before_action :check_expiration, only: [ :edit, :update ]

  # Displays the password reset request form
  def new
  end

  # Processes password reset request
  # Generates reset token if user exists and redirects with appropriate message
  def create
    @user = User.find_by(email: params[:email].downcase)
    if @user
      @user.generate_password_reset_token!
      # In a real app, send email here with PasswordMailer
      flash[:notice] = "Check your email for password reset instructions"
      redirect_to login_path
    else
      flash.now[:alert] = "Email address not found"
      render :new, status: :unprocessable_entity
    end
  end

  # Displays the password reset form for users with valid reset token
  def edit
  end

  # Processes new password submission
  # Updates password if valid and clears reset token
  def update
    if params[:user][:password].empty?
      @user.errors.add(:password, "can't be empty")
      render :edit, status: :unprocessable_entity
    elsif @user.update(user_params)
      @user.clear_password_reset!
      flash[:notice] = "Password has been reset successfully"
      redirect_to login_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def get_user
    @user = User.find_by(password_reset_token: params[:id])
  end

  def valid_user
    return if @user
    flash[:alert] = "Invalid password reset link"
    redirect_to login_path
  end

  def check_expiration
    return unless @user.password_reset_expired?
    flash[:alert] = "Password reset has expired"
    redirect_to new_password_reset_path
  end
end
