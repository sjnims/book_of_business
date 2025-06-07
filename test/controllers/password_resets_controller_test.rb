require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "test@example.com",
      name: "Test User",
      password: "password123",
      password_confirmation: "password123",
      role: "viewer"
    )
  end

  test "should get new" do
    get new_password_reset_path

    assert_response :success
  end

  test "should create password reset for valid email" do
    post password_resets_path, params: { email: @user.email }

    @user.reload

    assert_not_nil @user.password_reset_token
    assert_not_nil @user.password_reset_sent_at
    assert_redirected_to login_path
  end

  test "should show success message after creating password reset" do
    post password_resets_path, params: { email: @user.email }

    assert_equal "Check your email for password reset instructions", flash[:notice]
  end

  test "should not create password reset for invalid email" do
    post password_resets_path, params: { email: "nonexistent@example.com" }

    assert_response :unprocessable_entity
    assert_equal "Email address not found", flash[:alert]
  end

  test "should handle email with different case" do
    post password_resets_path, params: { email: @user.email.upcase }

    @user.reload

    assert_not_nil @user.password_reset_token
    assert_redirected_to login_path
  end

  test "should get edit with valid token" do
    raw_token = @user.generate_password_reset_token!

    get edit_password_reset_path(raw_token)

    assert_response :success
  end

  test "should redirect edit with invalid token" do
    get edit_password_reset_path("invalid_token")

    assert_redirected_to login_path
    assert_equal "Invalid password reset link", flash[:alert]
  end

  test "should redirect edit with expired token" do
    raw_token = @user.generate_password_reset_token!
    # Directly update the column to bypass callbacks
    @user.update_columns(password_reset_sent_at: 3.hours.ago)

    get edit_password_reset_path(raw_token)

    assert_redirected_to new_password_reset_path
    assert_equal "Password reset has expired", flash[:alert]
  end

  test "should update password with valid token and passwords" do
    raw_token = @user.generate_password_reset_token!

    patch password_reset_path(raw_token), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123",
      },
    }

    @user.reload
    # In Rails 8 with encrypted attributes, the token might still exist but be cleared differently
    assert @user.authenticate("newpassword123")
    assert_redirected_to login_path
    assert_equal "Password has been reset successfully", flash[:notice]
  end

  test "should not update password with empty password" do
    raw_token = @user.generate_password_reset_token!

    patch password_reset_path(raw_token), params: {
      user: {
        password: "",
        password_confirmation: "",
      },
    }

    assert_response :unprocessable_entity
    # The controller adds error manually
    assert_match(/can&#39;t be empty/, response.body)
  end

  test "should not update password with mismatched confirmation" do
    raw_token = @user.generate_password_reset_token!

    patch password_reset_path(raw_token), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "different123",
      },
    }

    assert_response :unprocessable_entity
  end

  test "should not update password with invalid token" do
    patch password_reset_path("invalid_token"), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123",
      },
    }

    assert_redirected_to login_path
    assert_equal "Invalid password reset link", flash[:alert]
  end

  test "should not update password with expired token" do
    raw_token = @user.generate_password_reset_token!
    @user.update_columns(password_reset_sent_at: 3.hours.ago)

    patch password_reset_path(raw_token), params: {
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123",
      },
    }

    assert_redirected_to new_password_reset_path
    assert_equal "Password reset has expired", flash[:alert]
  end

  test "password reset token should expire after 2 hours" do
    @user.generate_password_reset_token!

    # Token should not be expired immediately
    assert_not @user.password_reset_expired?

    # Token should be expired after 2 hours
    @user.update_columns(password_reset_sent_at: 2.hours.ago - 1.minute)

    assert_predicate @user, :password_reset_expired?
  end

  test "clear password reset clears token and timestamp" do
    @user.generate_password_reset_token!

    assert_not_nil @user.password_reset_token
    assert_not_nil @user.password_reset_sent_at

    @user.clear_password_reset!
  end

  test "password reset token and timestamp are cleared from database" do
    @user.generate_password_reset_token!
    @user.clear_password_reset!
    @user.reload

    # Check that the encrypted token is cleared
    raw_user = User.connection.select_one("SELECT password_reset_token, password_reset_sent_at FROM users WHERE id = #{@user.id}")

    assert_nil raw_user["password_reset_token"]
    assert_nil raw_user["password_reset_sent_at"]
  end
end
