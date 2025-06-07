require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      email: "test@example.com",
      name: "Test User",
      password: "password123",
      password_confirmation: "password123",
      role: "viewer"
    )
  end

  test "should be valid with valid attributes" do
    assert_predicate @user, :valid?
  end

  test "should require email" do
    @user.email = nil

    assert_not @user.valid?
    assert_includes @user.errors[:email], "can't be blank"
  end

  test "should require name" do
    @user.name = nil

    assert_not @user.valid?
    assert_includes @user.errors[:name], "can't be blank"
  end

  test "should require valid email format" do
    @user.email = "invalid-email"

    assert_not @user.valid?
    assert_includes @user.errors[:email], "is invalid"
  end

  test "should have unique email" do
    @user.save!
    duplicate = User.new(
      email: "TEST@EXAMPLE.COM",
      name: "Another User",
      password: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
  end

  test "should downcase email before save" do
    @user.email = "TEST@EXAMPLE.COM"
    @user.save!

    assert_equal "test@example.com", @user.email
  end

  test "should require password on create" do
    @user.password = nil

    assert_not @user.valid?
    assert_includes @user.errors[:password], "can't be blank"
  end

  test "should require password minimum length on create" do
    @user.password = "short"
    @user.password_confirmation = "short"

    assert_not @user.valid?
    assert_includes @user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "should allow blank password on update" do
    @user.save!
    @user.reload

    # Update other attributes without password
    @user.name = "Updated Name"

    assert_predicate @user, :valid?
    assert @user.save
  end

  test "should validate password length on update if provided" do
    @user.save!
    @user.password = "short"
    @user.password_confirmation = "short"

    assert_not @user.valid?
    assert_includes @user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "should have secure password" do
    @user.save!

    assert @user.authenticate("password123")
    assert_not @user.authenticate("wrong_password")
  end

  test "should have default role of viewer" do
    user = User.new(
      email: "viewer@example.com",
      name: "Viewer",
      password: "password123"
    )

    assert_equal "viewer", user.role
  end

  test "should accept valid roles" do
    %w[viewer sales_rep manager admin].each do |role|
      @user.role = role

      assert_predicate @user, :valid?
    end
  end

  test "should have viewer role query method" do
    assert_predicate @user, :viewer?
    assert_not_predicate @user, :admin?
  end

  test "should have admin role query method" do
    @user.role = "admin"

    assert_predicate @user, :admin?
    assert_not_predicate @user, :viewer?
  end

  test "should generate password reset token" do
    @user.save!
    original_token = @user.password_reset_token

    @user.generate_password_reset_token!
    @user.reload

    assert_not_equal original_token, @user.password_reset_token
    assert_not_nil @user.password_reset_token
  end

  test "should set password reset timestamp" do
    @user.save!
    @user.generate_password_reset_token!
    @user.reload

    assert_not_nil @user.password_reset_sent_at
    assert_in_delta Time.current, @user.password_reset_sent_at, 1.second
  end

  test "should check if password reset expired" do
    @user.save!

    # No token set
    assert_predicate @user, :password_reset_expired?

    # Fresh token
    @user.generate_password_reset_token!

    assert_not_predicate @user, :password_reset_expired?

    # Expired token
    @user.password_reset_sent_at = 3.hours.ago
    @user.save!

    assert_predicate @user, :password_reset_expired?
  end

  test "should clear password reset timestamp" do
    @user.save!
    @user.generate_password_reset_token!
    @user.reload

    assert_not_nil @user.password_reset_sent_at

    @user.clear_password_reset!

    assert_nil @user.password_reset_sent_at
  end

  test "should be expired after clearing password reset" do
    @user.save!
    @user.generate_password_reset_token!

    assert_not_predicate @user, :password_reset_expired?

    @user.clear_password_reset!

    assert_predicate @user, :password_reset_expired?
  end
end
