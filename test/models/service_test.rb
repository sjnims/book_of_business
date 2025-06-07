require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  def setup
    @customer = Customer.create!(
      customer_id: "CUST001",
      name: "Test Customer"
    )

    @order = Order.create!(
      customer: @customer,
      order_number: "ORD001",
      sold_date: Date.current,
      order_type: "new_order"
    )

    @service = Service.new(
      order: @order,
      service_name: "Test Internet Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 100.00,
      nrcs: 500.00,
      annual_escalator: 3.0,
      status: "active",
      site: "TEST-01"
    )
  end

  test "should be valid with valid attributes" do
    assert_predicate @service, :valid?
  end

  test "should require service_name" do
    @service.service_name = nil

    assert_not @service.valid?
    assert_includes @service.errors[:service_name], "can't be blank"
  end

  test "should require valid service_type" do
    @service.service_type = "invalid"

    assert_not @service.valid?
    assert_includes @service.errors[:service_type], "is not included in the list"
  end

  test "should require valid status" do
    @service.status = "invalid"

    assert_not @service.valid?
    assert_includes @service.errors[:status], "is not included in the list"
  end

  test "should require positive term_months" do
    @service.term_months = 0

    assert_not @service.valid?
    assert_includes @service.errors[:term_months], "must be greater than 0"
  end

  test "should require billing end date after billing start date" do
    @service.billing_end_date = @service.billing_start_date - 1.day

    assert_not @service.valid?
    assert_includes @service.errors[:billing_end_date], "must be after billing start date"
  end

  test "should require rev rec end date after rev rec start date" do
    @service.rev_rec_end_date = @service.rev_rec_start_date - 1.day

    assert_not @service.valid?
    assert_includes @service.errors[:rev_rec_end_date], "must be after revenue recognition start date"
  end

  test "should validate term matches billing dates" do
    @service.term_months = 24

    assert_not @service.valid?
    assert_includes @service.errors[:term_months], "doesn't match the billing date range"
  end

  test "should calculate end dates from term if missing" do
    service = Service.new(
      order: @order,
      service_name: "Test",
      service_type: "internet",
      term_months: 24,
      billing_start_date: Date.current,
      rev_rec_start_date: Date.current,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.valid?

    assert_equal Date.current + 24.months - 1.day, service.billing_end_date
    assert_equal Date.current + 24.months - 1.day, service.rev_rec_end_date
  end

  test "should calculate revenue fields before save" do
    @service.save!

    assert_equal 100, @service.mrr
    assert_equal 1200, @service.arr
    assert_equal 1700, @service.tcv # 500 NRC + (100 * 12 months)
  end

  test "should calculate MRR with escalation" do
    service = Service.create!(
      order: @order,
      service_name: "Escalating Service",
      service_type: "internet",
      term_months: 36,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 36.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 36.months - 1.day,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 10.0, # 10% annual increase
      status: "active"
    )

    # Month 1: $100
    assert_equal 100, service.calculate_mrr_at_month(1)

    # Month 13: $100 * 1.10 = $110
    assert_equal 110, service.calculate_mrr_at_month(13)

    # Month 25: $100 * 1.10^2 = $121
    assert_equal 121, service.calculate_mrr_at_month(25)
  end

  test "should have active scope" do
    @service.save!

    assert_includes Service.active, @service

    @service.update!(status: "canceled")

    assert_not_includes Service.active, @service
  end

  test "should identify expiring services" do
    # Create a service that expires in 15 days
    expiring_service = Service.create!(
      order: @order,
      service_name: "Expiring Service",
      service_type: "internet",
      term_months: 1,
      billing_start_date: 16.days.ago,
      billing_end_date: 15.days.from_now,
      rev_rec_start_date: 16.days.ago,
      rev_rec_end_date: 15.days.from_now,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    assert_predicate expiring_service, :expiring_soon?
    assert_includes Service.expiring_soon, expiring_service
  end

  test "should identify expired services" do
    # Create an expired service
    expired_service = Service.create!(
      order: @order,
      service_name: "Expired Service",
      service_type: "internet",
      term_months: 1,
      billing_start_date: 32.days.ago,
      billing_end_date: 1.day.ago,
      rev_rec_start_date: 32.days.ago,
      rev_rec_end_date: 1.day.ago,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    assert_predicate expired_service, :expired?
    assert_includes Service.expired, expired_service
  end

  test "should calculate days remaining" do
    @service.billing_end_date = 30.days.from_now

    assert_equal 30, @service.days_remaining
  end

  test "should return display_name" do
    assert_equal "Test Internet Service (internet)", @service.display_name
  end

  test "should filter active services with by_status scope" do
    @service.save!

    active_service = Service.create!(
      order: @order,
      service_name: "Active Service",
      service_type: "voice",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    pending_service = Service.create!(
      order: @order,
      service_name: "Pending Service",
      service_type: "data",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 75,
      nrcs: 0,
      annual_escalator: 0,
      status: "pending_installation"
    )

    active_services = Service.by_status("active")

    assert_includes active_services, @service
    assert_includes active_services, active_service
    assert_not_includes active_services, pending_service
  end

  test "should filter pending services with by_status scope" do
    @service.save!

    pending_service = Service.create!(
      order: @order,
      service_name: "Pending Service",
      service_type: "data",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 75,
      nrcs: 0,
      annual_escalator: 0,
      status: "pending_installation"
    )

    pending_services = Service.by_status("pending_installation")

    assert_includes pending_services, pending_service
    assert_not_includes pending_services, @service
  end

  test "should filter internet services with by_type scope" do
    @service.save!

    voice_service = Service.create!(
      order: @order,
      service_name: "Voice Service",
      service_type: "voice",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    internet_services = Service.by_type("internet")

    assert_includes internet_services, @service
    assert_not_includes internet_services, voice_service
  end

  test "should filter voice services with by_type scope" do
    @service.save!

    voice_service = Service.create!(
      order: @order,
      service_name: "Voice Service",
      service_type: "voice",
      term_months: 12,
      billing_start_date: Date.current,
      billing_end_date: Date.current + 12.months - 1.day,
      rev_rec_start_date: Date.current,
      rev_rec_end_date: Date.current + 12.months - 1.day,
      units: 1,
      unit_price: 50,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    voice_services = Service.by_type("voice")

    assert_includes voice_services, voice_service
    assert_not_includes voice_services, @service
  end

  test "should allow zero values for pricing fields" do
    @service.unit_price = 0
    @service.nrcs = 0
    @service.annual_escalator = 0

    assert_predicate @service, :valid?
  end

  test "should allow maximum annual_escalator of 100" do
    @service.annual_escalator = 100

    assert_predicate @service, :valid?
  end

  test "should not allow annual_escalator over 100" do
    @service.annual_escalator = 100.1

    assert_not @service.valid?
    assert_includes @service.errors[:annual_escalator], "must be less than or equal to 100"
  end

  test "should return false for active? when not active" do
    @service.status = "pending_installation"

    assert_not @service.active?
  end

  test "should calculate MRR for last month of term" do
    assert_equal 100, @service.calculate_mrr_at_month(12)
  end

  test "should return zero MRR for months beyond term" do
    assert_equal 0, @service.calculate_mrr_at_month(13)
  end

  test "should return zero MRR for invalid month numbers" do
    assert_equal 0, @service.calculate_mrr_at_month(0)
    assert_equal 0, @service.calculate_mrr_at_month(-1)
  end

  test "should handle zero term_months for calculate_total_tcv" do
    @service.term_months = 0

    assert_equal 500, @service.calculate_total_tcv # Only NRCs
  end

  test "should handle zero term_months for calculate_average_mrr" do
    @service.term_months = 0

    assert_equal 0, @service.calculate_average_mrr
  end

  test "should not calculate end dates when already provided" do
    original_billing_end = @service.billing_end_date
    original_rev_rec_end = @service.rev_rec_end_date

    @service.valid?

    assert_equal original_billing_end, @service.billing_end_date
    assert_equal original_rev_rec_end, @service.rev_rec_end_date
  end

  test "should validate dates are equal edge case" do
    @service.billing_end_date = @service.billing_start_date

    assert_not @service.valid?
    assert_includes @service.errors[:billing_end_date], "must be after billing start date"
  end

  test "should handle expiring_soon? for inactive service" do
    @service.status = "canceled"
    @service.billing_end_date = 15.days.from_now

    assert_not @service.expiring_soon?
  end

  test "should handle expiring_soon? edge cases" do
    # Service expiring today
    @service.billing_end_date = Date.current

    assert_predicate @service, :expiring_soon?

    # Service expiring exactly 30 days from now
    @service.billing_end_date = 30.days.from_now

    assert_predicate @service, :expiring_soon?

    # Service expiring 31 days from now
    @service.billing_end_date = 31.days.from_now

    assert_not @service.expiring_soon?
  end

  test "should skip validation when required fields are missing" do
    # Test term_matches_billing_dates validation with missing fields
    service = Service.new(
      order: @order,
      service_name: "Test",
      service_type: "internet",
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Missing all date fields and term_months - validation should skip
    service.valid?

    assert_not service.errors[:term_months].include?("doesn't match the billing date range")
  end

  test "should calculate monthly_recurring_charge" do
    @service.units = 2
    @service.unit_price = 150

    assert_equal 300, @service.monthly_recurring_charge
  end

  test "should support all service types" do
    service_types = %w[internet voice data cloud managed_services equipment other]

    service_types.each do |type|
      @service.service_type = type

      assert_predicate @service, :valid?, "Service should be valid with type: #{type}"
    end
  end

  test "should support all status values" do
    statuses = %w[pending_installation active extended renewed canceled]

    statuses.each do |status|
      @service.status = status

      assert_predicate @service, :valid?, "Service should be valid with status: #{status}"
    end
  end
end
