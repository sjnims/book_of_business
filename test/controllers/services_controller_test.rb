require "test_helper"

class ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post login_url, params: { email: @user.email, password: "password123" }
    @order = orders(:order_one)
    @service = services(:internet_service)
  end

  test "should get new" do
    get new_order_service_url(@order)

    assert_response :success
    assert_select "h1", "Add Service to #{@order.display_name}"
  end

  test "should create service" do
    assert_difference("@order.services.count") do
      post order_services_url(@order), params: { service: {
        service_type: "internet",
        service_name: "100 Mbps Connection",
        term_months: 24,
        status: "pending_installation",
        units: 1,
        unit_price: 1000,
        nrcs: 500,
        annual_escalator: 3,
        billing_start_date: Time.zone.today,
        billing_end_date: Time.zone.today + 24.months,
        rev_rec_start_date: Time.zone.today,
        rev_rec_end_date: Time.zone.today + 24.months,
        site: "NYC",
      } }
    end

    assert_redirected_to order_url(@order)
    assert_equal "Service was successfully added.", flash[:notice]
  end

  test "should get edit" do
    get edit_order_service_url(@order, @service)

    assert_response :success
    assert_select "h1", "Edit Service for #{@order.display_name}"
  end

  test "should update service" do
    patch order_service_url(@order, @service), params: { service: {
      service_name: "Updated Service Name",
    } }

    assert_redirected_to order_url(@order)
    assert_equal "Service was successfully updated.", flash[:notice]
  end

  test "should destroy service" do
    assert_difference("@order.services.count", -1) do
      delete order_service_url(@order, @service)
    end

    assert_redirected_to order_url(@order)
    assert_equal "Service was successfully removed.", flash[:notice]
  end

  test "should show service" do
    get order_service_url(@order, @service)

    assert_response :success
    assert_select "h1", @service.display_name
  end

  test "should not create service with invalid params" do
    assert_no_difference("@order.services.count") do
      post order_services_url(@order), params: { service: {
        service_type: "",
        service_name: "",
        term_months: nil,
        units: nil,
        unit_price: nil,
      } }
    end

    assert_response :unprocessable_entity
    assert_select "h1", "Add Service to #{@order.display_name}"
  end

  test "should not update service with invalid params" do
    patch order_service_url(@order, @service), params: { service: {
      service_type: "",
      service_name: "",
      term_months: -1,
      units: 0,
      unit_price: -100,
    } }

    assert_response :unprocessable_entity
    assert_select "h1", "Edit Service for #{@order.display_name}"
  end

  test "requires authentication" do
    delete logout_url
    get new_order_service_url(@order)

    assert_redirected_to login_url
  end

  test "requires authentication for show" do
    delete logout_url
    get order_service_url(@order, @service)

    assert_redirected_to login_url
  end

  test "requires authentication for create" do
    delete logout_url
    assert_no_difference("Service.count") do
      post order_services_url(@order), params: { service: {
        service_name: "Test Service",
      } }
    end

    assert_redirected_to login_url
  end

  test "requires authentication for edit" do
    delete logout_url
    get edit_order_service_url(@order, @service)

    assert_redirected_to login_url
  end

  test "requires authentication for update" do
    delete logout_url
    patch order_service_url(@order, @service), params: { service: {
      service_name: "Updated Name",
    } }

    assert_redirected_to login_url
  end

  test "requires authentication for destroy" do
    delete logout_url
    assert_no_difference("Service.count") do
      delete order_service_url(@order, @service)
    end

    assert_redirected_to login_url
  end
end
