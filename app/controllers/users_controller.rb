# Manages user account creation by administrators
#
# Only administrators can create new user accounts
# Handles displaying the user creation form and processing new user registrations
class UsersController < ApplicationController
  before_action :require_admin, only: [ :new, :create ]

  # Displays the new user registration form
  # Only accessible by admin users
  def new
    @user = User.new
  end

  # Creates a new user account
  # Processes form submission and saves user with specified role
  def create
    @user = User.new(user_params)
    # Explicitly set role from params only if admin
    @user.role = params[:user][:role] if current_user.admin? && params[:user][:role].present?

    if @user.save
      flash[:notice] = "User created successfully"
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    # Remove role from permitted params to prevent mass assignment
    params.require(:user).permit(:email, :name, :password, :password_confirmation)
  end
end
