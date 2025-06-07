require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      email: "admin@test.com",
      name: "Admin User",
      password: "password123",
      role: "admin"
    )

    @non_admin = User.create!(
      email: "user@test.com",
      name: "Regular User",
      password: "password123",
      role: "viewer"
    )
  end

  test "should redirect new when not logged in" do
    get new_user_path

    assert_redirected_to root_path
    assert_equal "You must be an admin to access this page", flash[:alert]
  end

  test "should redirect new when not admin" do
    post login_path, params: { email: @non_admin.email, password: "password123" }

    get new_user_path

    assert_redirected_to root_path
    assert_equal "You must be an admin to access this page", flash[:alert]
  end

  test "should get new when admin" do
    post login_path, params: { email: @admin.email, password: "password123" }

    get new_user_path

    assert_response :success
  end

  test "should redirect create when not logged in" do
    post users_path, params: { user: { email: "new@test.com", name: "New User", password: "password123", password_confirmation: "password123", role: "viewer" } }

    assert_redirected_to root_path
    assert_equal "You must be an admin to access this page", flash[:alert]
  end

  test "should redirect create when not admin" do
    post login_path, params: { email: @non_admin.email, password: "password123" }

    post users_path, params: { user: { email: "new@test.com", name: "New User", password: "password123", password_confirmation: "password123", role: "viewer" } }

    assert_redirected_to root_path
    assert_equal "You must be an admin to access this page", flash[:alert]
  end

  test "should create user when admin with valid params" do
    post login_path, params: { email: @admin.email, password: "password123" }

    assert_difference("User.count", 1) do
      post users_path, params: {
        user: {
          email: "new@test.com",
          name: "New User",
          password: "password123",
          password_confirmation: "password123",
          role: "viewer",
        },
      }
    end

    assert_redirected_to root_path
    assert_equal "User created successfully", flash[:notice]
  end

  test "should create user with correct attributes" do
    post login_path, params: { email: @admin.email, password: "password123" }

    post users_path, params: {
      user: {
        email: "new@test.com",
        name: "New User",
        password: "password123",
        password_confirmation: "password123",
        role: "viewer",
      },
    }

    new_user = User.find_by(email: "new@test.com")

    assert_not_nil new_user
    assert_equal "New User", new_user.name
    assert_equal "viewer", new_user.role
  end

  test "should create user with different roles" do
    post login_path, params: { email: @admin.email, password: "password123" }

    %w[viewer sales_rep manager admin].each_with_index do |role, index|
      assert_difference("User.count", 1) do
        post users_path, params: {
          user: {
            email: "#{role}#{index}@test.com",
            name: "#{role.humanize} User",
            password: "password123",
            password_confirmation: "password123",
            role: role,
          },
        }
      end

      new_user = User.find_by(email: "#{role}#{index}@test.com")

      assert_equal role, new_user.role
    end
  end

  test "should not create user with invalid params" do
    post login_path, params: { email: @admin.email, password: "password123" }

    assert_no_difference("User.count") do
      post users_path, params: {
        user: {
          email: "",
          name: "",
          password: "",
          password_confirmation: "",
          role: "viewer",
        },
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create user with mismatched passwords" do
    post login_path, params: { email: @admin.email, password: "password123" }

    assert_no_difference("User.count") do
      post users_path, params: {
        user: {
          email: "new@test.com",
          name: "New User",
          password: "password123",
          password_confirmation: "different",
          role: "viewer",
        },
      }
    end

    assert_response :unprocessable_entity
  end

  test "should create user with default role when role not specified" do
    post login_path, params: { email: @admin.email, password: "password123" }

    assert_difference("User.count", 1) do
      post users_path, params: {
        user: {
          email: "norole@test.com",
          name: "No Role User",
          password: "password123",
          password_confirmation: "password123",
          # Note: no role specified
        },
      }
    end

    new_user = User.find_by(email: "norole@test.com")

    assert_equal "viewer", new_user.role # Should default to viewer
  end

  test "should not create duplicate user" do
    post login_path, params: { email: @admin.email, password: "password123" }

    assert_no_difference("User.count") do
      post users_path, params: {
        user: {
          email: @admin.email,
          name: "Duplicate User",
          password: "password123",
          password_confirmation: "password123",
          role: "viewer",
        },
      }
    end

    assert_response :unprocessable_entity
  end
end
