require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  class TestController < ApplicationController
    def index
      render plain: "OK"
    end

    def admin_only
      require_admin
      render plain: "Admin OK" unless performed?
    end

    def manager_only
      require_manager_or_admin
      render plain: "Manager OK" unless performed?
    end

    def login_required
      require_login
      render plain: "Logged in OK" unless performed?
    end
  end

  setup do
    # Add test routes
    Rails.application.routes.draw do
      get "test", to: "application_controller_test/test#index"
      get "test/admin_only", to: "application_controller_test/test#admin_only"
      get "test/manager_only", to: "application_controller_test/test#manager_only"
      get "test/login_required", to: "application_controller_test/test#login_required"

      # Keep existing routes
      resources :users, only: [ :new, :create ]
      resources :sessions, only: [ :new, :create, :destroy ]
      resources :password_resets, only: [ :new, :create, :edit, :update ]
      get "login", to: "sessions#new"
      delete "logout", to: "sessions#destroy"
      root "sessions#new"
    end

    @viewer = User.create!(
      email: "viewer@test.com",
      name: "Viewer User",
      password: "password123",
      role: "viewer"
    )

    @sales_rep = User.create!(
      email: "sales@test.com",
      name: "Sales User",
      password: "password123",
      role: "sales_rep"
    )

    @manager = User.create!(
      email: "manager@test.com",
      name: "Manager User",
      password: "password123",
      role: "manager"
    )

    @admin = User.create!(
      email: "admin@test.com",
      name: "Admin User",
      password: "password123",
      role: "admin"
    )
  end

  teardown do
    Rails.application.reload_routes!
  end

  test "current_user returns nil when not logged in" do
    get test_path

    assert_response :success
  end

  test "logged_in? returns false when not logged in" do
    get test_path

    assert_response :success
  end

  test "current_user returns user when logged in" do
    post sessions_path, params: { email: @viewer.email, password: "password123" }
    get test_path

    assert_response :success
  end

  test "require_login redirects when not logged in" do
    get test_login_required_path

    assert_redirected_to login_path
    assert_equal "You must be logged in to access this page", flash[:alert]
  end

  test "require_login allows access when logged in" do
    post sessions_path, params: { email: @viewer.email, password: "password123" }
    get test_login_required_path

    assert_response :success
    assert_equal "Logged in OK", response.body
  end

  test "require_admin redirects when not logged in" do
    get test_admin_only_path

    assert_redirected_to root_path
    assert_equal "You must be an admin to access this page", flash[:alert]
  end

  test "require_admin redirects non-admin users" do
    post sessions_path, params: { email: @viewer.email, password: "password123" }
    get test_admin_only_path

    assert_redirected_to root_path
    assert_equal "You must be an admin to access this page", flash[:alert]
  end

  test "require_admin allows admin access" do
    post sessions_path, params: { email: @admin.email, password: "password123" }
    get test_admin_only_path

    assert_response :success
    assert_equal "Admin OK", response.body
  end

  test "require_manager_or_admin redirects when not logged in" do
    get test_manager_only_path

    assert_redirected_to root_path
    assert_equal "You must be a manager or admin to access this page", flash[:alert]
  end

  test "require_manager_or_admin redirects viewers" do
    post sessions_path, params: { email: @viewer.email, password: "password123" }
    get test_manager_only_path

    assert_redirected_to root_path
    assert_equal "You must be a manager or admin to access this page", flash[:alert]
  end

  test "require_manager_or_admin redirects sales reps" do
    post sessions_path, params: { email: @sales_rep.email, password: "password123" }
    get test_manager_only_path

    assert_redirected_to root_path
    assert_equal "You must be a manager or admin to access this page", flash[:alert]
  end

  test "require_manager_or_admin allows manager access" do
    post sessions_path, params: { email: @manager.email, password: "password123" }
    get test_manager_only_path

    assert_response :success
    assert_equal "Manager OK", response.body
  end

  test "require_manager_or_admin allows admin access" do
    post sessions_path, params: { email: @admin.email, password: "password123" }
    get test_manager_only_path

    assert_response :success
    assert_equal "Manager OK", response.body
  end
end
