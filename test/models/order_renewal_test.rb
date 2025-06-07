require "test_helper"

class OrderRenewalTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:acme)
    @original_order = orders(:order_one)
  end

  test "renewal order requires original order reference" do
    renewal = Order.new(
      customer: @customer,
      order_number: "REN-001",
      order_type: "renewal",
      sold_date: Time.zone.today,
      tcv: @original_order.tcv * 1.1,  # 10% increase
      created_by: users(:admin)
    )

    assert_not renewal.valid?
    assert_includes renewal.errors[:original_order_id], "is required for renewal orders"
  end

  test "renewal order is valid with original order reference" do
    renewal = Order.new(
      customer: @customer,
      order_number: "REN-001",
      order_type: "renewal",
      sold_date: Time.zone.today,
      tcv: @original_order.tcv * 1.1,
      original_order: @original_order,
      created_by: users(:admin)
    )

    assert_predicate renewal, :valid?, renewal.errors.full_messages.join(", ")
  end

  test "is_renewal? returns true for renewal orders" do
    renewal = Order.new(order_type: "renewal")

    assert_predicate renewal, :is_renewal?
  end

  test "is_renewal? returns false for other order types" do
    new_order = Order.new(order_type: "new_order")

    assert_not new_order.is_renewal?
  end

  test "renewal order tracks original order relationship" do
    # First renewal
    first_renewal = Order.create!(
      customer: @customer,
      order_number: "REN-GEN1",
      order_type: "renewal",
      sold_date: Time.zone.today - 365.days,
      tcv: 55_000,
      original_order: @original_order,
      created_by: users(:admin)
    )

    # Second renewal (renewal of a renewal)
    second_renewal = Order.create!(
      customer: @customer,
      order_number: "REN-GEN2",
      order_type: "renewal",
      sold_date: Time.zone.today,
      tcv: 60_000,
      original_order: first_renewal,
      created_by: users(:admin)
    )

    assert_equal @original_order, first_renewal.original_order
    assert_equal first_renewal, second_renewal.original_order
  end

  test "renewal orders appear in parent order's renewal_orders collection" do
    first_renewal = Order.create!(
      customer: @customer,
      order_number: "REN-COL1",
      order_type: "renewal",
      sold_date: Time.zone.today - 365.days,
      tcv: 55_000,
      original_order: @original_order,
      created_by: users(:admin)
    )

    second_renewal = Order.create!(
      customer: @customer,
      order_number: "REN-COL2",
      order_type: "renewal",
      sold_date: Time.zone.today,
      tcv: 60_000,
      original_order: first_renewal,
      created_by: users(:admin)
    )

    assert_includes @original_order.renewal_orders, first_renewal
    assert_includes first_renewal.renewal_orders, second_renewal
  end

  test "renewal order appears in renewals scope" do
    renewal = Order.create!(
      customer: @customer,
      order_number: "REN-SCOPE",
      order_type: "renewal",
      sold_date: Time.zone.today,
      tcv: 55_000,
      original_order: @original_order,
      created_by: users(:admin)
    )

    assert_includes Order.renewals, renewal
    assert_not_includes Order.new_orders, renewal
  end

  test "renewal order can have increased pricing" do
    # Add services to original order
    @original_order.services.create!(
      service_type: "internet",
      service_name: "Original Internet Service",
      term_months_as_sold: 12,
      status: "active",
      units: 1,
      unit_price: 1000,
      nrcs: 500,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today - 12.months,
      rev_rec_start_date_as_sold: Time.zone.today - 12.months
    )

    renewal = Order.new(
      customer: @customer,
      order_number: "REN-PRICE",
      order_type: "renewal",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    # Renewal with price increase
    renewal.services.build(
      service_type: "internet",
      service_name: "Renewed Internet Service",
      term_months_as_sold: 12,
      status: "pending_installation",
      units: 1,
      unit_price: 1100,  # 10% increase
      nrcs: 0,  # No NRCs on renewal
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_predicate renewal, :valid?
    assert renewal.save
  end

  test "renewal order can have different terms than original" do
    renewal = Order.new(
      customer: @customer,
      order_number: "REN-TERM",
      order_type: "renewal",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    # Original might be 12 months, renewal is 24 months
    renewal.services.build(
      service_type: "internet",
      service_name: "Extended Term Renewal",
      term_months_as_sold: 24,
      status: "pending_installation",
      units: 1,
      unit_price: 950,  # Discount for longer term
      nrcs: 0,
      annual_escalator: 2,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_predicate renewal, :valid?
  end

  test "original order cannot be deleted when renewals exist" do
    Order.create!(
      customer: @customer,
      order_number: "REN-RESTRICT",
      order_type: "renewal",
      sold_date: Time.zone.today,
      tcv: 55_000,
      original_order: @original_order,
      created_by: users(:admin)
    )

    assert_raises(ActiveRecord::RecordNotDestroyed) do
      @original_order.destroy!
    end

    assert Order.exists?(@original_order.id)
  end

  test "renewal order inherits customer from original order" do
    renewal = Order.new(
      customer: @original_order.customer,
      order_number: "REN-CUSTOMER",
      order_type: "renewal",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    assert_equal @original_order.customer, renewal.customer
  end

  test "other order types do not require original order" do
    order_types = %w[new_order upgrade downgrade cancellation]

    order_types.each do |type|
      order = Order.new(
        customer: @customer,
        order_number: "TEST-#{type.upcase}",
        sold_date: Time.zone.today,
        order_type: type,
        created_by: users(:admin)
      )

      assert_predicate order, :valid?, "Order with type #{type} should be valid without original_order"
    end
  end

  test "renewal order with partial services" do
    # Original order has multiple services
    @original_order.services.create!(
      service_type: "internet",
      service_name: "Internet Service",
      term_months_as_sold: 12,
      status: "active",
      units: 1,
      unit_price: 1000,
      nrcs: 500,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today - 12.months,
      rev_rec_start_date_as_sold: Time.zone.today - 12.months
    )

    @original_order.services.create!(
      service_type: "voice",
      service_name: "Voice Service",
      term_months_as_sold: 12,
      status: "active",
      units: 5,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date_as_sold: Time.zone.today - 12.months,
      rev_rec_start_date_as_sold: Time.zone.today - 12.months
    )

    # Renewal only includes internet service (voice not renewed)
    renewal = Order.new(
      customer: @customer,
      order_number: "REN-PARTIAL",
      order_type: "renewal",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    renewal.services.build(
      service_type: "internet",
      service_name: "Renewed Internet Service Only",
      term_months_as_sold: 12,
      status: "pending_installation",
      units: 1,
      unit_price: 1100,
      nrcs: 0,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_predicate renewal, :valid?
    assert_equal 1, renewal.services.size
  end
end
