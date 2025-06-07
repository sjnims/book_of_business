require "test_helper"

class OrderPartialDeBookTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:acme)

    # Create an original order with multiple services
    @original_order = Order.create!(
      customer: @customer,
      order_number: "ORIG-001",
      order_type: "new_order",
      sold_date: 30.days.ago,
      tcv: 100_000,
      created_by: users(:admin)
    )

    # Add service 1: 10 units of internet
    @service1 = @original_order.services.create!(
      service_type: "internet",
      service_name: "Fiber Internet",
      term_months_as_sold: 36,
      status: "pending_installation",
      units: 10,
      unit_price: 200,
      nrcs: 1000,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    # Add service 2: 5 units of voice
    @service2 = @original_order.services.create!(
      service_type: "voice",
      service_name: "VoIP Service",
      term_months_as_sold: 36,
      status: "pending_installation",
      units: 5,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )
  end

  test "can create partial de-book for subset of units" do
    # De-book 3 units of internet service
    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-PARTIAL-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book.services.build(
      service_type: "internet",
      service_name: "Partial De-book - Fiber Internet",
      term_months_as_sold: 36,
      status: "canceled",
      units: -3,
      unit_price: 200,
      nrcs: -300,  # Proportional NRCs
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_predicate de_book, :valid?
    assert de_book.save
  end

  test "can create de-book for one service type only" do
    # De-book all voice services, leave internet untouched
    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-VOICE-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book.services.build(
      service_type: "voice",
      service_name: "Full De-book - VoIP Service",
      term_months_as_sold: 36,
      status: "canceled",
      units: -5,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_predicate de_book, :valid?
    assert de_book.save
  end

  test "cannot de-book more units than pending" do
    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-EXCESS-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book.services.build(
      service_type: "internet",
      service_name: "Excess De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -15,  # More than the 10 available
      unit_price: 200,
      nrcs: -1500,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_not de_book.valid?
    assert_includes de_book.services.first.errors[:units], "cannot exceed available pending units (10 remaining)"
  end

  test "cannot de-book service type not in pending state" do
    # Change internet service to active
    @service1.update!(status: "active")

    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-ACTIVE-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book.services.build(
      service_type: "internet",
      service_name: "Invalid De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -3,
      unit_price: 200,
      nrcs: -300,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_not de_book.valid?
    assert_includes de_book.services.first.errors[:service_type], "does not exist in pending state on the original order"
  end

  test "multiple de-books track remaining available units" do
    # First de-book: 3 units of internet
    de_book1 = Order.create!(
      customer: @customer,
      order_number: "DE-BOOK-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book1.services.create!(
      service_type: "internet",
      service_name: "First Partial De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -3,
      unit_price: 200,
      nrcs: -300,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    # Second de-book: try to de-book 8 more units (should fail, only 7 remaining)
    de_book2 = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-002",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book2.services.build(
      service_type: "internet",
      service_name: "Second Partial De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -8,
      unit_price: 200,
      nrcs: -800,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_not de_book2.valid?
    assert_includes de_book2.services.first.errors[:units], "cannot exceed available pending units (7 remaining)"
  end

  test "available_for_de_book returns correct quantities" do
    available = @original_order.available_for_de_book

    assert_equal 10, available["internet"]
    assert_equal 5, available["voice"]
  end

  test "available_for_de_book updates after partial de-book" do
    # Create a partial de-book
    de_book = Order.create!(
      customer: @customer,
      order_number: "DE-BOOK-TEST-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book.services.create!(
      service_type: "internet",
      service_name: "Partial De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -4,
      unit_price: 200,
      nrcs: -400,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    # Check available units after de-book
    available_after = @original_order.reload.available_for_de_book

    assert_equal 6, available_after["internet"]
    assert_equal 5, available_after["voice"]
  end

  test "de-book with multiple service types in single order" do
    de_book = Order.new(
      customer: @customer,
      order_number: "DE-BOOK-MULTI-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    # Partial de-book of internet
    de_book.services.build(
      service_type: "internet",
      service_name: "Partial Internet De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -2,
      unit_price: 200,
      nrcs: -200,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    # Full de-book of voice
    de_book.services.build(
      service_type: "voice",
      service_name: "Full Voice De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -5,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    assert_predicate de_book, :valid?
    assert de_book.save
  end

  test "de-book correctly updates available quantities" do
    # Create de-book from previous test
    de_book = Order.create!(
      customer: @customer,
      order_number: "DE-BOOK-MULTI-001",
      order_type: "de_book",
      sold_date: Time.zone.today,
      original_order: @original_order,
      created_by: users(:admin)
    )

    de_book.services.create!(
      service_type: "internet",
      service_name: "Partial Internet De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -2,
      unit_price: 200,
      nrcs: -200,
      annual_escalator: 3,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    de_book.services.create!(
      service_type: "voice",
      service_name: "Full Voice De-book",
      term_months_as_sold: 36,
      status: "canceled",
      units: -5,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date_as_sold: Time.zone.today,
      rev_rec_start_date_as_sold: Time.zone.today
    )

    # Check remaining available
    available = @original_order.reload.available_for_de_book

    assert_equal 8, available["internet"]
    assert_nil available["voice"]  # All voice units de-booked
  end
end
