# Handles user authentication sessions (login/logout)
#
# Manages user login sessions by:
# - Displaying login form
# - Authenticating credentials
# - Creating/destroying sessions
# - Redirecting based on authentication status
class SessionsController < ApplicationController
  # Displays the login form
  # Redirects to root if user is already logged in
  def new
    redirect_to root_path if logged_in?
  end

  # Processes login attempt
  # Authenticates user credentials and creates session if valid
  def create
    user = User.find_by(email: params[:email].downcase)

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      flash[:notice] = "Welcome back, #{user.name}!"
      redirect_to root_path
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  # Logs out the current user
  # Clears session and redirects to login page
  def destroy
    session.delete(:user_id)
    @current_user = nil
    flash[:notice] = "You have been logged out"
    redirect_to login_path
  end
end
