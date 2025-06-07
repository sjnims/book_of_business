require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    post login_url, params: { email: @user.email, password: "password123" }
    @order = orders(:order_one)
    @customer = customers(:acme)
  end

  test "should get index" do
    get orders_url

    assert_response :success
    assert_select "h1", "Orders"
  end

  test "should get new" do
    get new_order_url

    assert_response :success
    assert_select "h1", "New Order"
  end

  test "should create order" do
    assert_difference("Order.count") do
      post orders_url, params: { order: {
        customer_id: @customer.id,
        order_number: "NEW-ORD-001",
        sold_date: Time.zone.today,
        tcv: 50_000,
        order_type: "new_order",
        sales_rep: "Test Rep",
        site: "NYC",
        notes: "Test notes",
      } }
    end

    assert_redirected_to order_url(Order.last)
    assert_equal "Order was successfully created.", flash[:notice]
  end

  test "should show order" do
    get order_url(@order)

    assert_response :success
    assert_select "h1", "Order #{@order.order_number}"
  end

  test "should get edit" do
    get edit_order_url(@order)

    assert_response :success
    assert_select "h1", "Edit Order"
  end

  test "should update order" do
    patch order_url(@order), params: { order: {
      notes: "Updated notes",
    } }

    assert_redirected_to order_url(@order)
    assert_equal "Order was successfully updated.", flash[:notice]
  end

  test "should destroy order" do
    # Use order_two which has no renewals
    order_to_delete = orders(:order_two)
    assert_difference("Order.count", -1) do
      delete order_url(order_to_delete)
    end

    assert_redirected_to orders_url
    assert_equal "Order was successfully destroyed.", flash[:notice]
  end

  test "should not create order with invalid params" do
    assert_no_difference("Order.count") do
      post orders_url, params: { order: {
        customer_id: nil,
        order_number: "",
        sold_date: nil,
        tcv: nil,
        order_type: "invalid_type",
      } }
    end

    assert_response :unprocessable_entity
    assert_select "h1", "New Order"
  end

  test "should not update order with invalid params" do
    patch order_url(@order), params: { order: {
      customer_id: nil,
      order_number: "",
      sold_date: nil,
      tcv: -1000,
    } }

    assert_response :unprocessable_entity
    assert_select "h1", "Edit Order"
  end

  test "requires authentication" do
    delete logout_url
    get orders_url

    assert_redirected_to login_url
  end

  test "requires authentication for show" do
    delete logout_url
    get order_url(@order)

    assert_redirected_to login_url
  end

  test "requires authentication for new" do
    delete logout_url
    get new_order_url

    assert_redirected_to login_url
  end

  test "requires authentication for create" do
    delete logout_url
    assert_no_difference("Order.count") do
      post orders_url, params: { order: {
        customer_id: @customer.id,
        order_number: "TEST-001",
      } }
    end

    assert_redirected_to login_url
  end

  test "requires authentication for edit" do
    delete logout_url
    get edit_order_url(@order)

    assert_redirected_to login_url
  end

  test "requires authentication for update" do
    delete logout_url
    patch order_url(@order), params: { order: {
      notes: "Updated notes",
    } }

    assert_redirected_to login_url
  end

  test "requires authentication for destroy" do
    delete logout_url
    assert_no_difference("Order.count") do
      delete order_url(@order)
    end

    assert_redirected_to login_url
  end
end
