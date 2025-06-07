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
    # With 3% annual escalator and 12-month term, no escalation in first year
    # TCV = (12 * $100) + $500 NRC = $1,700
    assert_equal 1700, @service.tcv
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

    # Get monthly breakdown to verify escalation
    monthly_breakdown = service.monthly_revenue_breakdown

    # Month 1: $100
    assert_equal 100, monthly_breakdown[0][:mrr]

    # The RevenueCalculator uses annual escalation (not monthly compounding)
    # Month 13: $100 * 1.10 = $110.00
    assert_in_delta(110.00, monthly_breakdown[12][:mrr])

    # Month 25: $100 * 1.10 * 1.10 = $121.00
    assert_in_delta(121.00, monthly_breakdown[24][:mrr])
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
    @service.save!
    monthly_breakdown = @service.monthly_revenue_breakdown

    # With 3% annual escalator and 12-month term, no escalation in first year
    # Month 12: $100 (no escalation yet)
    assert_in_delta(100.00, monthly_breakdown.last[:mrr])
  end

  test "should not include months beyond term in breakdown" do
    @service.save!
    monthly_breakdown = @service.monthly_revenue_breakdown

    # Should only have 12 months in the breakdown
    assert_equal 12, monthly_breakdown.length
  end

  test "should handle monthly breakdown with valid dates" do
    @service.save!
    monthly_breakdown = @service.monthly_revenue_breakdown

    # Should have valid months
    assert_not_empty monthly_breakdown
    assert monthly_breakdown.all? { |month| (month[:mrr]).positive? }
  end

  test "should handle zero term_months for calculate_tcv" do
    @service.term_months = 0

    # With zero term_months, validation will fail
    assert_not @service.valid?
    assert_includes @service.errors[:term_months], "must be greater than 0"

    # The RevenueCalculator returns 0 for invalid services
    assert_equal 0, @service.calculate_tcv
  end

  test "should handle zero term_months for calculate_gaap_mrr" do
    @service.term_months = 0
    @service.save

    assert_equal 0, @service.calculate_gaap_mrr
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

  test "should require billing_start_date" do
    @service.billing_start_date = nil

    assert_not @service.valid?
    assert_includes @service.errors[:billing_start_date], "can't be blank"
  end

  test "should require rev_rec_start_date" do
    @service.rev_rec_start_date = nil

    assert_not @service.valid?
    assert_includes @service.errors[:rev_rec_start_date], "can't be blank"
  end

  test "should require units to be positive" do
    @service.units = 0

    assert_not @service.valid?
    assert_includes @service.errors[:units], "must be greater than 0"
  end

  test "should not allow negative units" do
    @service.units = -1

    assert_not @service.valid?
    assert_includes @service.errors[:units], "must be greater than 0"
  end

  test "should not allow negative unit_price" do
    @service.unit_price = -1

    assert_not @service.valid?
    assert_includes @service.errors[:unit_price], "must be greater than or equal to 0"
  end

  test "should not allow negative nrcs" do
    @service.nrcs = -100

    assert_not @service.valid?
    assert_includes @service.errors[:nrcs], "must be greater than or equal to 0"
  end

  test "should not allow negative annual_escalator" do
    @service.annual_escalator = -1

    assert_not @service.valid?
    assert_includes @service.errors[:annual_escalator], "must be greater than or equal to 0"
  end

  test "should require integer term_months" do
    @service.term_months = 12.5

    assert_not @service.valid?
    assert_includes @service.errors[:term_months], "must be an integer"
  end

  test "should have association to customer through order" do
    assert_equal @customer, @service.customer
  end

  test "should calculate revenue fields when MRR is already set" do
    @service.mrr = 200
    @service.save!

    # MRR should stay as user-entered value
    assert_equal 200, @service.mrr
    assert_equal 2400, @service.arr
  end

  test "should validate all edge cases for date validations" do
    # Test skipping validation when dates are nil
    service = Service.new(
      order: @order,
      service_name: "Test",
      service_type: "internet",
      term_months: 12,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Missing dates - should have validation errors for required dates
    assert_not service.valid?
    assert_includes service.errors[:billing_start_date], "can't be blank"
    assert_includes service.errors[:rev_rec_start_date], "can't be blank"
  end

  test "should handle calculate_end_dates_from_term when dates missing" do
    service = Service.new(
      order: @order,
      service_name: "Test",
      service_type: "internet",
      term_months: 12,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Without start dates, end dates should not be calculated
    service.valid?

    assert_nil service.billing_end_date
    assert_nil service.rev_rec_end_date
  end

  test "should handle validation edge case with billing date mismatch" do
    # Test with date variation outside acceptable range
    @service.billing_end_date = @service.billing_start_date + @service.term_months.months + 2.days

    assert_not @service.valid?
    assert_includes @service.errors[:term_months], "doesn't match the billing date range"
  end

  test "should calculate all revenues using calculate_all_revenues method" do
    @service.save!

    revenues = @service.calculate_all_revenues

    assert_kind_of Hash, revenues
  end

  test "calculate_all_revenues returns all required keys" do
    @service.save!

    revenues = @service.calculate_all_revenues

    assert revenues.key?(:tcv)
    assert revenues.key?(:mrr)
    assert revenues.key?(:arr)
  end

  test "calculate_all_revenues includes gaap_mrr and monthly_values" do
    @service.save!

    revenues = @service.calculate_all_revenues

    assert revenues.key?(:gaap_mrr)
    assert revenues.key?(:monthly_values)
  end

  test "calculate_all_revenues returns correct values" do
    @service.save!

    revenues = @service.calculate_all_revenues

    assert_equal 100, revenues[:mrr]
    assert_equal 1200, revenues[:arr]
    assert_equal 1700, revenues[:tcv]
  end

  test "should calculate net new value using calculate_net_new_value method" do
    @service.save!

    # Test with no original service (new service)
    net_new = @service.calculate_net_new_value(nil)

    assert_equal @service.tcv, net_new

    # Create an original service to compare
    original = Service.create!(
      order: @order,
      service_name: "Original Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.current - 1.year,
      billing_end_date: Date.current - 1.day,
      rev_rec_start_date: Date.current - 1.year,
      rev_rec_end_date: Date.current - 1.day,
      units: 1,
      unit_price: 80,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Calculate net new value (upgrade)
    net_new_upgrade = @service.calculate_net_new_value(original)
    expected_net_new = @service.tcv - original.tcv

    assert_equal expected_net_new, net_new_upgrade
  end
end
