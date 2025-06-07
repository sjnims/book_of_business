require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  def setup
    @customer = Customer.new(
      customer_id: "TEST001",
      name: "Test Customer",
      email: "test@example.com",
      phone: "555-1234",
      billing_address: "123 Test St"
    )
  end

  test "should be valid with valid attributes" do
    assert_predicate @customer, :valid?
  end

  test "should require customer_id" do
    @customer.customer_id = nil

    assert_not @customer.valid?
    assert_includes @customer.errors[:customer_id], "can't be blank"
  end

  test "should require name" do
    @customer.name = nil

    assert_not @customer.valid?
    assert_includes @customer.errors[:name], "can't be blank"
  end

  test "should have unique customer_id" do
    @customer.save!
    duplicate = Customer.new(customer_id: "test001", name: "Another")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:customer_id], "has already been taken"
  end

  test "should normalize customer_id to uppercase" do
    @customer.customer_id = "test001"
    @customer.save!

    assert_equal "TEST001", @customer.customer_id
  end

  test "should validate email format" do
    @customer.email = "invalid-email"

    assert_not @customer.valid?
    assert_includes @customer.errors[:email], "is invalid"
  end

  test "should allow blank email" do
    @customer.email = ""

    assert_predicate @customer, :valid?
  end

  test "should calculate total MRR" do
    @customer.save!
    order = @customer.orders.create!(
      order_number: "ORD001",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: users(:admin)
    )
    order.services.create!(
      service_name: "Test Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    assert_equal 100, @customer.total_mrr
  end

  test "should have active scope" do
    @customer.save!
    order = @customer.orders.create!(
      order_number: "ORD001",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: users(:admin)
    )
    order.services.create!(
      service_name: "Test Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    assert_includes Customer.active, @customer
  end

  test "should search by name" do
    @customer.save!

    assert_includes Customer.search("Test"), @customer
  end

  test "should search by customer_id" do
    @customer.save!

    assert_includes Customer.search("TEST001"), @customer
  end

  test "should search by email" do
    @customer.save!

    assert_includes Customer.search("test@example"), @customer
  end

  test "should return empty for non-existent search" do
    @customer.save!

    assert_empty Customer.search("nonexistent")
  end

  test "should validate technical_contact_email format" do
    @customer.technical_contact_email = "invalid-email"

    assert_not @customer.valid?
    assert_includes @customer.errors[:technical_contact_email], "is invalid"
  end

  test "should allow blank technical_contact_email" do
    @customer.technical_contact_email = ""

    assert_predicate @customer, :valid?
  end

  test "should allow valid technical_contact_email" do
    @customer.technical_contact_email = "tech@example.com"

    assert_predicate @customer, :valid?
  end

  test "should return display_name" do
    assert_equal "TEST001 - Test Customer", @customer.display_name
  end

  test "should return active_services" do
    @customer.save!
    order = @customer.orders.create!(
      order_number: "ORD002",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: users(:admin)
    )

    active_service = order.services.create!(
      service_name: "Active Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    inactive_service = order.services.create!(
      service_name: "Inactive Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      status: "canceled"
    )

    active_services = @customer.active_services

    assert_includes active_services, active_service
    assert_not_includes active_services, inactive_service
  end

  test "should calculate total_arr" do
    @customer.save!
    order = @customer.orders.create!(
      order_number: "ORD003",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: users(:admin)
    )

    order.services.create!(
      service_name: "Service 1",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    order.services.create!(
      service_name: "Service 2",
      service_type: "voice",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # ARR = MRR * 12
    # Service 1: 100 * 12 = 1200
    # Service 2: 50 * 12 = 600
    # Total: 1800
    assert_equal 1800, @customer.total_arr
  end

  test "should return true for has_active_services? when active services exist" do
    @customer.save!
    order = @customer.orders.create!(
      order_number: "ORD004",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: users(:admin)
    )
    order.services.create!(
      service_name: "Active Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    assert_predicate @customer, :has_active_services?
  end

  test "should return false for has_active_services? when no active services" do
    @customer.save!
    order = @customer.orders.create!(
      order_number: "ORD005",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: users(:admin)
    )
    order.services.create!(
      service_name: "Canceled Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "canceled"
    )

    assert_not @customer.has_active_services?
  end

  test "should return false for has_active_services? when no services" do
    @customer.save!

    assert_not @customer.has_active_services?
  end

  test "should order customers by name with by_name scope" do
    clean_database!

    customer_b = Customer.create!(customer_id: "CUST002", name: "B Customer")
    customer_a = Customer.create!(customer_id: "CUST001", name: "A Customer")
    customer_c = Customer.create!(customer_id: "CUST003", name: "C Customer")

    ordered_customers = Customer.by_name

    assert_equal [ customer_a, customer_b, customer_c ], ordered_customers.to_a
  end

  test "should not delete customer with orders" do
    @customer.save!
    @customer.orders.create!(
      order_number: "ORD006",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: users(:admin)
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @customer.destroy!
    end
  end

  test "should delete customer without orders" do
    @customer.save!

    assert_difference "Customer.count", -1 do
      @customer.destroy!
    end
  end

  test "should strip whitespace from customer_id" do
    @customer.customer_id = "  TEST002  "
    @customer.save!

    assert_equal "TEST002", @customer.customer_id
  end

  test "should handle nil customer_id in normalization" do
    @customer.customer_id = nil
    @customer.valid?

    assert_nil @customer.customer_id
  end

  test "should be case insensitive for search" do
    @customer.save!

    assert_includes Customer.search("test"), @customer
    assert_includes Customer.search("TEST"), @customer
    assert_includes Customer.search("TeSt"), @customer
  end
end
