require "test_helper"

class OrderDeBookTest < ActiveSupport::TestCase
  setup do
    @original_order = orders(:order_one)
    @customer = customers(:acme)
  end

  test "de-book order requires original order reference" do
    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      tcv: -@original_order.tcv
    )

    assert_not de_book.valid?
    assert_includes de_book.errors[:original_order_id], "is required for de-book orders"
  end

  test "de-book order is valid with original order reference" do
    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      tcv: -@original_order.tcv,
      original_order: @original_order
    )

    assert_predicate de_book, :valid?, de_book.errors.full_messages.join(", ")
  end

  test "is_de_book? returns true for de-book orders" do
    de_book = Order.new(order_type: "de_book")

    assert_predicate de_book, :is_de_book?
  end

  test "is_de_book? returns false for other order types" do
    regular_order = Order.new(order_type: "new_order")

    assert_not regular_order.is_de_book?
  end

  test "de-book order can have negative financial values" do
    # Add a pending service to the original order
    @original_order.services.create!(
      service_type: "internet",
      service_name: "Pending Internet Service",
      term_months: 24,
      status: "pending_installation",
      units: 2,
      unit_price: 1000,
      nrcs: 1000,
      annual_escalator: 0,
      billing_start_date: Time.zone.today,
      rev_rec_start_date: Time.zone.today
    )

    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-002",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order
    )

    # Create services with negative values
    de_book.services.build(
      service_type: "internet",
      service_name: "De-booked Internet Service",
      term_months: 24,
      status: "canceled",
      units: -1,
      unit_price: 1000,
      nrcs: -500,
      annual_escalator: 0,
      billing_start_date: Time.zone.today,
      rev_rec_start_date: Time.zone.today
    )

    assert_predicate de_book, :valid?
  end

  test "de-book order appears in regular order scopes" do
    de_book = Order.create!(
      customer: @customer,
      order_number: "DE-BOOK-003",
      order_type: "de_book",
      sold_date: Time.zone.today,
      tcv: -10_000,
      original_order: @original_order
    )

    assert_includes Order.all, de_book
    assert_includes Order.by_date, de_book
    assert_includes Order.by_type("de_book"), de_book
  end
end
