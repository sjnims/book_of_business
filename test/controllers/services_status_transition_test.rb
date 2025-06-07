require "test_helper"

class ServicesStatusTransitionTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @customer = customers(:acme)
    @order = orders(:order_one)
    @active_service = services(:internet_service)

    # Create a pending service for testing activation
    @pending_service = @order.services.create!(
      service_name: "Pending Service",
      service_type: "internet",
      status: "pending_installation",
      term_months: 12,
      billing_start_date: Date.current,
      rev_rec_start_date: Date.current,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    # Log in as the user
    post login_url, params: { email: @user.email, password: "password123" }
  end

  test "should activate a pending service" do
    assert_equal "pending_installation", @pending_service.status

    patch order_service_url(@order, @pending_service), params: {
      service: { action: "activate" },
    }

    assert_redirected_to order_service_path(@order, @pending_service)
    assert_equal "Service status updated successfully.", flash[:notice]
  end

  test "activated service changes status to active" do
    patch order_service_url(@order, @pending_service), params: {
      service: { action: "activate" },
    }

    @pending_service.reload

    assert_equal "active", @pending_service.status
  end

  test "should not activate an already active service" do
    patch order_service_url(@order, @active_service), params: {
      service: { action: "activate" },
    }

    assert_redirected_to order_service_path(@order, @active_service)
    assert_equal "Unable to update service status.", flash[:alert]
  end

  test "active service remains active when activation attempted" do
    assert_equal "active", @active_service.status

    patch order_service_url(@order, @active_service), params: {
      service: { action: "activate" },
    }

    @active_service.reload

    assert_equal "active", @active_service.status
  end

  test "should cancel an active service" do
    patch order_service_url(@order, @active_service), params: {
      service: { action: "cancel" },
    }

    assert_redirected_to order_service_path(@order, @active_service)
    assert_equal "Service status updated successfully.", flash[:notice]
  end

  test "canceled service changes status from active to canceled" do
    assert_equal "active", @active_service.status

    patch order_service_url(@order, @active_service), params: {
      service: { action: "cancel" },
    }

    @active_service.reload

    assert_equal "canceled", @active_service.status
  end

  test "should renew an active service" do
    patch order_service_url(@order, @active_service), params: {
      service: { action: "renew" },
    }

    assert_redirected_to order_service_path(@order, @active_service)
    assert_equal "Service status updated successfully.", flash[:notice]
  end

  test "renewed service changes status from active to renewed" do
    assert_equal "active", @active_service.status

    patch order_service_url(@order, @active_service), params: {
      service: { action: "renew" },
    }

    @active_service.reload

    assert_equal "renewed", @active_service.status
  end

  test "should handle invalid action gracefully" do
    patch order_service_url(@order, @active_service), params: {
      service: { action: "invalid_action" },
    }

    assert_redirected_to order_service_path(@order, @active_service)
    assert_equal "Unable to update service status.", flash[:alert]
  end

  test "should require authentication for status transitions" do
    delete logout_url

    patch order_service_url(@order, @pending_service), params: {
      service: { action: "activate" },
    }

    assert_redirected_to login_url
  end

  test "should update service normally when no action is provided" do
    patch order_service_url(@order, @active_service), params: {
      service: {
        service_name: "Updated Service Name",
        units: 5,
      },
    }

    assert_redirected_to @order
    assert_equal "Service was successfully updated.", flash[:notice]
  end

  test "service attributes are updated when no action provided" do
    patch order_service_url(@order, @active_service), params: {
      service: {
        service_name: "Updated Service Name",
        units: 5,
      },
    }

    @active_service.reload

    assert_equal "Updated Service Name", @active_service.service_name
    assert_equal 5, @active_service.units
  end
end
