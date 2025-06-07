require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      name: "Test User",
      password: "password123",
      role: "viewer"
    )
  end

  test "should get new" do
    get login_path

    assert_response :success
  end

  test "should redirect to root if already logged in" do
    post login_path, params: { email: @user.email, password: "password123" }

    get login_path

    assert_redirected_to root_path
  end

  test "should create session with valid credentials" do
    post login_path, params: { email: @user.email, password: "password123" }

    assert_redirected_to root_path
    assert_equal "Welcome back, Test User!", flash[:notice]
    assert_equal @user.id, session[:user_id]
  end

  test "should create session with case-insensitive email" do
    post login_path, params: { email: "TEST@EXAMPLE.COM", password: "password123" }

    assert_redirected_to root_path
    assert_equal "Welcome back, Test User!", flash[:notice]
    assert_equal @user.id, session[:user_id]
  end

  test "should not create session with invalid email" do
    post login_path, params: { email: "wrong@example.com", password: "password123" }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
    assert_nil session[:user_id]
  end

  test "should not create session with invalid password" do
    post login_path, params: { email: @user.email, password: "wrongpassword" }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
    assert_nil session[:user_id]
  end

  test "should not create session with blank email" do
    post login_path, params: { email: "", password: "password123" }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
    assert_nil session[:user_id]
  end

  test "should not create session with blank password" do
    post login_path, params: { email: @user.email, password: "" }

    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
    assert_nil session[:user_id]
  end

  test "should destroy session" do
    # Log in first
    post login_path, params: { email: @user.email, password: "password123" }

    # Log out
    delete logout_path

    assert_redirected_to login_path
    assert_equal "You have been logged out", flash[:notice]
  end

  test "should clear session on logout" do
    # Log in first
    post login_path, params: { email: @user.email, password: "password123" }

    assert_equal @user.id, session[:user_id]

    # Log out
    delete logout_path

    assert_nil session[:user_id]
  end

  test "destroy should clear current_user instance variable" do
    # Log in first
    post login_path, params: { email: @user.email, password: "password123" }

    # Log out
    delete logout_path

    # Verify we're logged out by trying to access a protected page
    get new_user_path

    assert_redirected_to root_path
  end
end
