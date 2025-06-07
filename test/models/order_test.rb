require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def setup
    @customer = Customer.create!(
      customer_id: "CUST001",
      name: "Test Customer"
    )

    @order = Order.new(
      customer: @customer,
      order_number: "ORD001",
      sold_date: Date.current,
      order_type: "new_order",
      sales_rep: "Test Rep",
      site: "TEST-01"
    )
  end

  test "should be valid with valid attributes" do
    assert_predicate @order, :valid?
  end

  test "should require order_number" do
    @order.order_number = nil

    assert_not @order.valid?
    assert_includes @order.errors[:order_number], "can't be blank"
  end

  test "should require sold_date" do
    @order.sold_date = nil

    assert_not @order.valid?
    assert_includes @order.errors[:sold_date], "can't be blank"
  end

  test "should require valid order_type" do
    @order.order_type = "invalid_type"

    assert_not @order.valid?
    assert_includes @order.errors[:order_type], "is not included in the list"
  end

  test "should have unique order_number" do
    @order.save!
    duplicate = Order.new(
      customer: @customer,
      order_number: "ord001",
      sold_date: Date.current,
      order_type: "new_order"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:order_number], "has already been taken"
  end

  test "should normalize order_number to uppercase" do
    @order.order_number = "ord001"
    @order.save!

    assert_equal "ORD001", @order.order_number
  end

  test "should belong to customer" do
    assert_respond_to @order, :customer
    assert_equal @customer, @order.customer
  end

  test "should have optional original_order relationship" do
    @order.save!
    renewal = Order.create!(
      customer: @customer,
      order_number: "ORD002",
      sold_date: Date.current,
      order_type: "renewal",
      original_order: @order
    )

    assert_equal @order, renewal.original_order
    assert_includes @order.renewal_orders, renewal
  end

  test "should calculate totals before save" do
    @order.save!
    @order.services.create!(
      service_name: "Test Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 1200,
      annual_escalator: 0,
      status: "active"
    )

    # Force recalculation by saving the order
    @order.save!
    @order.reload

    assert_equal 2400, @order.tcv
    assert_equal 100, @order.baseline_mrr
    assert_equal 100, @order.gaap_mrr
  end

  test "should include order in recent scope" do
    @order.save!

    assert_includes Order.recent, @order
  end

  test "should include order in new_orders scope" do
    @order.save!

    assert_includes Order.new_orders, @order
  end

  test "should handle renewals scope correctly" do
    @order.save!

    assert_empty Order.renewals

    renewal = Order.create!(
      customer: @customer,
      order_number: "ORD002",
      sold_date: Date.current,
      order_type: "renewal"
    )

    assert_includes Order.renewals, renewal
  end

  test "should accept nested attributes for services" do
    order = Order.new(
      customer: @customer,
      order_number: "ORD003",
      sold_date: Date.current,
      order_type: "new_order",
      services_attributes: [
        {
          service_name: "Nested Service",
          service_type: "internet",
          term_months: 12,
          billing_start_date: Date.current,
          billing_end_date: Date.current + 12.months - 1.day,
          rev_rec_start_date: Date.current,
          rev_rec_end_date: Date.current + 12.months - 1.day,
          units: 1,
          unit_price: 100,
          nrcs: 0,
          annual_escalator: 0,
          status: "active",
        },
      ]
    )

    assert order.save
    assert_equal 1, order.services.count
    assert_equal "Nested Service", order.services.first.service_name
  end

  test "should return display_name" do
    assert_equal "ORD001 - Test Customer", @order.display_name
  end

  test "should return true for is_renewal? when order_type is renewal" do
    @order.order_type = "renewal"

    assert_predicate @order, :is_renewal?
  end

  test "should return false for is_renewal? when order_type is not renewal" do
    assert_not @order.is_renewal?
  end

  test "should return true for is_new_order? when order_type is new_order" do
    assert_predicate @order, :is_new_order?
  end

  test "should return false for is_new_order? when order_type is not new_order" do
    @order.order_type = "renewal"

    assert_not @order.is_new_order?
  end

  test "should return true for has_active_services? when active services exist" do
    @order.save!
    @order.services.create!(
      service_name: "Active Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    assert_predicate @order, :has_active_services?
  end

  test "should return false for has_active_services? when no active services" do
    @order.save!
    @order.services.create!(
      service_name: "Canceled Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "canceled"
    )

    assert_not @order.has_active_services?
  end

  test "should return active_services" do
    @order.save!

    active_service = @order.services.create!(
      service_name: "Active Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    inactive_service = @order.services.create!(
      service_name: "Inactive Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      status: "pending_installation"
    )

    active_services = @order.active_services

    assert_includes active_services, active_service
    assert_not_includes active_services, inactive_service
  end

  test "should order by date with by_date scope" do
    older_order = Order.create!(
      customer: @customer,
      order_number: "ORD004",
      sold_date: 10.days.ago,
      order_type: "new_order"
    )

    newer_order = Order.create!(
      customer: @customer,
      order_number: "ORD005",
      sold_date: 1.day.ago,
      order_type: "new_order"
    )

    orders = Order.by_date

    assert_equal newer_order, orders.first
    assert_equal older_order, orders.last
  end

  test "should filter new orders with by_type scope" do
    @order.save!

    renewal = Order.create!(
      customer: @customer,
      order_number: "ORD006",
      sold_date: Date.current,
      order_type: "renewal"
    )

    upgrade = Order.create!(
      customer: @customer,
      order_number: "ORD007",
      sold_date: Date.current,
      order_type: "upgrade"
    )

    new_orders = Order.by_type("new_order")

    assert_includes new_orders, @order
    assert_not_includes new_orders, renewal
    assert_not_includes new_orders, upgrade
  end

  test "should filter renewals with by_type scope" do
    @order.save!

    renewal = Order.create!(
      customer: @customer,
      order_number: "ORD006",
      sold_date: Date.current,
      order_type: "renewal"
    )

    renewals = Order.by_type("renewal")

    assert_includes renewals, renewal
    assert_not_includes renewals, @order
  end

  test "should filter by date range with in_date_range scope" do
    @order.save!

    old_order = Order.create!(
      customer: @customer,
      order_number: "ORD008",
      sold_date: 30.days.ago,
      order_type: "new_order"
    )

    recent_order = Order.create!(
      customer: @customer,
      order_number: "ORD009",
      sold_date: 5.days.ago,
      order_type: "new_order"
    )

    orders_in_range = Order.in_date_range(7.days.ago, Date.current)

    assert_includes orders_in_range, @order
    assert_includes orders_in_range, recent_order
    assert_not_includes orders_in_range, old_order
  end

  test "should validate tcv is non-negative" do
    @order.tcv = -100

    assert_not @order.valid?
    assert_includes @order.errors[:tcv], "must be greater than or equal to 0"
  end

  test "should allow nil tcv" do
    @order.tcv = nil

    assert_predicate @order, :valid?
  end

  test "should validate baseline_mrr is non-negative" do
    @order.baseline_mrr = -50

    assert_not @order.valid?
    assert_includes @order.errors[:baseline_mrr], "must be greater than or equal to 0"
  end

  test "should allow nil baseline_mrr" do
    @order.baseline_mrr = nil

    assert_predicate @order, :valid?
  end

  test "should validate gaap_mrr is non-negative" do
    @order.gaap_mrr = -25

    assert_not @order.valid?
    assert_includes @order.errors[:gaap_mrr], "must be greater than or equal to 0"
  end

  test "should allow nil gaap_mrr" do
    @order.gaap_mrr = nil

    assert_predicate @order, :valid?
  end

  test "should strip whitespace from order_number" do
    @order.order_number = "  ORD002  "
    @order.save!

    assert_equal "ORD002", @order.order_number
  end

  test "should handle nil order_number in normalization" do
    @order.order_number = nil
    @order.valid?

    assert_nil @order.order_number
  end

  test "should calculate GAAP MRR with multiple services of different terms" do
    @order.save!

    # Service 1: 12 month term, $1200 recurring revenue
    @order.services.create!(
      service_name: "Service 1",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Service 2: 24 month term, $2400 recurring revenue
    @order.services.create!(
      service_name: "Service 2",
      service_type: "voice",
      term_months: 24,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 24.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 24.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    @order.save!
    @order.reload

    # Weighted average term = (12*1200 + 24*2400) / (1200+2400) = 72000/3600 = 20 months
    # GAAP MRR = 3600 / 20 = 180
    assert_equal 180, @order.gaap_mrr
  end

  test "should return 0 for GAAP MRR when no services" do
    @order.save!

    assert_equal 0, @order.calculate_gaap_mrr
  end

  test "should return 0 for GAAP MRR when only NRCs" do
    @order.save!

    @order.services.create!(
      service_name: "NRC Only Service",
      service_type: "equipment",
      term_months: 1,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 1.month - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 1.month - 1.day,
      units: 1,
      unit_price: 0,
      nrcs: 1000,
      annual_escalator: 0,
      status: "active"
    )

    @order.save!
    @order.reload

    assert_equal 0, @order.gaap_mrr
  end

  test "should not delete order with renewal orders" do
    @order.save!

    _renewal = Order.create!(
      customer: @customer,
      order_number: "ORD010",
      sold_date: Date.current,
      order_type: "renewal",
      original_order: @order
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @order.destroy!
    end
  end

  test "should delete order without renewal orders" do
    @order.save!

    assert_difference "Order.count", -1 do
      @order.destroy!
    end
  end

  test "should support all order types" do
    order_types = %w[new_order renewal upgrade downgrade cancellation]

    order_types.each do |type|
      order = Order.new(
        customer: @customer,
        order_number: "ORD-#{type}",
        sold_date: Date.current,
        order_type: type
      )

      assert_predicate order, :valid?, "Order should be valid with type: #{type}"
    end
  end

  test "should limit recent scope to 10 orders" do
    # Create 15 orders
    15.times do |i|
      Order.create!(
        customer: @customer,
        order_number: "ORD#{100 + i}",
        sold_date: Date.current - i.days,
        order_type: "new_order"
      )
    end

    recent_orders = Order.recent

    assert_equal 10, recent_orders.count

    # Verify they are the most recent ones
    assert_equal "ORD100", recent_orders.first.order_number
    assert_equal "ORD109", recent_orders.last.order_number
  end

  test "should allow destroying services through nested attributes" do
    @order.save!
    service = @order.services.create!(
      service_name: "Service to Delete",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    @order.update!(
      services_attributes: [
        {
          id: service.id,
          _destroy: true,
        },
      ]
    )

    assert_equal 0, @order.services.count
  end
end
