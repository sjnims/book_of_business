class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :logged_in?

  # Returns the currently logged in user based on session
  #
  # Returns User instance if logged in, nil otherwise
  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  # Checks if a user is currently logged in
  #
  # Returns true if user is logged in, false otherwise
  def logged_in?
    !!current_user
  end

  # Requires user to be logged in to access the page
  # Redirects to login page with alert if not authenticated
  def require_login
    return if logged_in?

    flash[:alert] = "You must be logged in to access this page"
    redirect_to login_path
  end

  # Requires user to have admin role to access the page
  # Redirects to root with alert if not admin
  def require_admin
    return if logged_in? && current_user.admin?

    flash[:alert] = "You must be an admin to access this page"
    redirect_to root_path
  end

  # Requires user to have manager or admin role to access the page
  # Redirects to root with alert if not authorized
  def require_manager_or_admin
    return if logged_in? && (current_user.manager? || current_user.admin?)

    flash[:alert] = "You must be a manager or admin to access this page"
    redirect_to root_path
  end
end
