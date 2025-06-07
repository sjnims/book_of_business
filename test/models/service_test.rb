require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:admin)
    @customer = Customer.create!(
      customer_id: "CUST001",
      name: "Test Customer"
    )

    @order = Order.create!(
      customer: @customer,
      order_number: "ORD001",
      sold_date: Date.current,
      order_type: "new_order",
      created_by: @user
    )

    @service = Service.new(
      order: @order,
      service_name: "Test Internet Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
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
    @service.term_months_as_sold = 0

    assert_not @service.valid?
    assert_includes @service.errors[:term_months_as_sold], "must be greater than 0"
  end

  test "should require billing end date after billing start date" do
    @service.billing_end_date_as_sold = @service.billing_start_date_as_sold - 1.day

    assert_not @service.valid?
    assert_includes @service.errors[:billing_end_date_as_sold], "must be after billing start date"
  end

  test "should require rev rec end date after rev rec start date" do
    @service.rev_rec_end_date_as_sold = @service.rev_rec_start_date_as_sold - 1.day

    assert_not @service.valid?
    assert_includes @service.errors[:rev_rec_end_date_as_sold], "must be after revenue recognition start date"
  end

  test "should validate term matches billing dates" do
    @service.term_months_as_sold = 24

    assert_not @service.valid?
    assert_includes @service.errors[:term_months_as_sold], "doesn't match the as_sold billing date range"
  end

  test "should calculate end dates from term if missing" do
    service = Service.new(
      order: @order,
      service_name: "Test",
      service_type: "internet",
      term_months_as_sold: 24,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.valid?

    assert_equal Date.current + 24.months - 1.day, service.billing_end_date_as_sold
    assert_equal Date.current + 24.months - 1.day, service.rev_rec_end_date_as_sold
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
      term_months_as_sold: 36,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 36.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 36.months - 1.day,
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
      term_months_as_sold: 1,
      billing_start_date_as_sold: 16.days.ago,
      billing_end_date_as_sold: 15.days.from_now,
      rev_rec_start_date_as_sold: 16.days.ago,
      rev_rec_end_date_as_sold: 15.days.from_now,
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
      term_months_as_sold: 1,
      billing_start_date_as_sold: 32.days.ago,
      billing_end_date_as_sold: 1.day.ago,
      rev_rec_start_date_as_sold: 32.days.ago,
      rev_rec_end_date_as_sold: 1.day.ago,
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
    @service.billing_end_date_as_delivered = 30.days.from_now

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

    pending_service = Service.create!(
      order: @order,
      service_name: "Pending Service",
      service_type: "data",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
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
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      billing_end_date_as_sold: Date.current + 12.months - 1.day,
      rev_rec_start_date_as_sold: Date.current,
      rev_rec_end_date_as_sold: Date.current + 12.months - 1.day,
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
    @service.term_months_as_sold = 0

    # With zero term_months, validation will fail
    assert_not @service.valid?
    assert_includes @service.errors[:term_months_as_sold], "must be greater than 0"

    # The RevenueCalculator returns 0 for invalid services
    assert_equal 0, @service.calculate_tcv
  end

  test "should handle zero term_months for calculate_gaap_mrr" do
    @service.term_months_as_sold = 0
    @service.save

    assert_equal 0, @service.calculate_gaap_mrr
  end

  test "should not calculate end dates when already provided" do
    original_billing_end = @service.billing_end_date_as_sold
    original_rev_rec_end = @service.rev_rec_end_date_as_sold

    @service.valid?

    assert_equal original_billing_end, @service.billing_end_date_as_sold
    assert_equal original_rev_rec_end, @service.rev_rec_end_date_as_sold
  end

  test "should validate dates are equal edge case" do
    @service.billing_end_date_as_sold = @service.billing_start_date_as_sold

    assert_not @service.valid?
    assert_includes @service.errors[:billing_end_date_as_sold], "must be after billing start date"
  end

  test "should handle expiring_soon? for inactive service" do
    @service.status = "canceled"
    @service.billing_end_date_as_sold = 15.days.from_now

    assert_not @service.expiring_soon?
  end

  test "should handle expiring_soon? edge cases" do
    # Service expiring today
    @service.billing_end_date_as_delivered = Date.current

    assert_predicate @service, :expiring_soon?

    # Service expiring exactly 30 days from now
    @service.billing_end_date_as_delivered = 30.days.from_now

    assert_predicate @service, :expiring_soon?

    # Service expiring 31 days from now
    @service.billing_end_date_as_delivered = 31.days.from_now

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

    assert_not service.errors[:term_months_as_sold].include?("doesn't match the billing date range")
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
    @service.billing_start_date_as_sold = nil

    assert_not @service.valid?
    assert_includes @service.errors[:billing_start_date_as_sold], "can't be blank"
  end

  test "should require rev_rec_start_date" do
    @service.rev_rec_start_date_as_sold = nil

    assert_not @service.valid?
    assert_includes @service.errors[:rev_rec_start_date_as_sold], "can't be blank"
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
    @service.term_months_as_sold = 12.5

    assert_not @service.valid?
    assert_includes @service.errors[:term_months_as_sold], "must be an integer"
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
      term_months_as_sold: 12,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Missing dates - should have validation errors for required dates
    assert_not service.valid?
    assert_includes service.errors[:billing_start_date_as_sold], "can't be blank"
    assert_includes service.errors[:rev_rec_start_date_as_sold], "can't be blank"
  end

  test "should handle calculate_end_dates_from_term when dates missing" do
    service = Service.new(
      order: @order,
      service_name: "Test",
      service_type: "internet",
      term_months_as_sold: 12,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Without start dates, end dates should not be calculated
    service.valid?

    assert_nil service.billing_end_date_as_sold
    assert_nil service.rev_rec_end_date_as_sold
  end

  test "should handle validation edge case with billing date mismatch" do
    # Test with date variation outside acceptable range
    @service.billing_end_date_as_sold = @service.billing_start_date_as_sold + @service.term_months_as_sold.months + 2.days

    assert_not @service.valid?
    assert_includes @service.errors[:term_months_as_sold], "doesn't match the as_sold billing date range"
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
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current - 1.year,
      billing_end_date_as_sold: Date.current - 1.day,
      rev_rec_start_date_as_sold: Date.current - 1.year,
      rev_rec_end_date_as_sold: Date.current - 1.day,
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

  # Tests for status transition methods
  test "should activate pending installation service" do
    @service.status = "pending_installation"
    @service.save!

    assert @service.activate!
    assert_equal "active", @service.status
  end

  test "should not activate non-pending service" do
    @service.status = "active"
    @service.save!

    assert_not @service.activate!
    assert_equal "active", @service.status
  end

  test "should cancel pending installation service" do
    @service.status = "pending_installation"
    @service.save!

    assert @service.cancel!
    assert_equal "canceled", @service.status
  end

  test "should cancel active service" do
    @service.status = "active"
    @service.save!

    assert @service.cancel!
    assert_equal "canceled", @service.status
  end

  test "should not cancel already canceled service" do
    @service.status = "canceled"
    @service.save!

    assert_not @service.cancel!
    assert_equal "canceled", @service.status
  end

  test "should renew active service" do
    @service.status = "active"
    @service.save!

    assert @service.renew!
    assert_equal "renewed", @service.status
  end

  test "should renew extended service" do
    @service.status = "extended"
    @service.save!

    assert @service.renew!
    assert_equal "renewed", @service.status
  end

  test "should not renew pending installation service" do
    @service.status = "pending_installation"
    @service.save!

    assert_not @service.renew!
    assert_equal "pending_installation", @service.status
  end

  test "should update to extended status when expired" do
    # Create a service that was started in the past and is now expired
    expired_service = Service.create!(
      order: @order,
      service_name: "Expired Service",
      service_type: "internet",
      term_months_as_sold: 1,
      billing_start_date_as_sold: 32.days.ago,
      billing_end_date_as_sold: 2.days.ago,
      rev_rec_start_date_as_sold: 32.days.ago,
      rev_rec_end_date_as_sold: 2.days.ago,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    assert_predicate expired_service, :should_be_extended?
    assert expired_service.update_extended_status!
    assert_equal "extended", expired_service.status
  end

  test "should not update to extended status when not expired" do
    @service.status = "active"
    @service.save!

    assert_not @service.should_be_extended?
    assert_not @service.update_extended_status!
    assert_equal "active", @service.status
  end

  test "should not update to extended status when not active" do
    # Create an expired service with canceled status
    canceled_service = Service.create!(
      order: @order,
      service_name: "Canceled Expired Service",
      service_type: "internet",
      term_months_as_sold: 1,
      billing_start_date_as_sold: 32.days.ago,
      billing_end_date_as_sold: 2.days.ago,
      rev_rec_start_date_as_sold: 32.days.ago,
      rev_rec_end_date_as_sold: 2.days.ago,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "canceled"
    )

    assert_not canceled_service.should_be_extended?
    assert_not canceled_service.update_extended_status!
    assert_equal "canceled", canceled_service.status
  end

  # Tests for extend_by_months
  test "should extend service by months" do
    @service.status = "active"
    @service.save!

    original_term = @service.term_months_as_delivered

    assert @service.extend_by_months(6)
    assert_equal original_term + 6, @service.term_months_as_delivered
  end

  test "should update billing and rev rec dates when extending service" do
    @service.status = "active"
    @service.save!

    original_billing_end = @service.billing_end_date_as_delivered
    original_rev_rec_end = @service.rev_rec_end_date_as_delivered

    @service.extend_by_months(6)

    assert_equal original_billing_end + 6.months, @service.billing_end_date_as_delivered
    assert_equal original_rev_rec_end + 6.months, @service.rev_rec_end_date_as_delivered
  end

  test "should extend extended service by months" do
    @service.status = "extended"
    @service.save!

    original_term = @service.term_months_as_delivered

    assert @service.extend_by_months(3)
    assert_equal original_term + 3, @service.term_months_as_delivered
  end

  test "should not extend canceled service" do
    @service.status = "canceled"
    @service.save!

    original_term = @service.term_months_as_delivered

    assert_not @service.extend_by_months(6)
    assert_equal original_term, @service.term_months_as_delivered
  end

  test "should allow extension for active and extended statuses" do
    @service.status = "active"

    assert_predicate @service, :can_extend?

    @service.status = "extended"

    assert_predicate @service, :can_extend?
  end

  test "should not allow extension for other statuses" do
    @service.status = "pending_installation"

    assert_not @service.can_extend?

    @service.status = "canceled"

    assert_not @service.can_extend?

    @service.status = "renewed"

    assert_not @service.can_extend?
  end

  # Tests for needs_extension scope
  test "should identify services needing extension" do
    # Active service that is expired
    expired_active = Service.create!(
      order: @order,
      service_name: "Expired Active Service",
      service_type: "internet",
      term_months_as_sold: 1,
      billing_start_date_as_sold: 32.days.ago,
      billing_end_date_as_sold: 1.day.ago,
      rev_rec_start_date_as_sold: 32.days.ago,
      rev_rec_end_date_as_sold: 1.day.ago,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Active service not expired
    @service.save!

    needs_extension = Service.needs_extension

    assert_includes needs_extension, expired_active
    assert_not_includes needs_extension, @service
  end

  # Tests for de-book order validations
  test "should require negative units and nrcs for de-book orders" do
    de_book_customer = Customer.create!(
      customer_id: "CUST002",
      name: "De-book Customer"
    )

    original_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-ORIG",
      sold_date: 30.days.ago,
      order_type: "new_order",
      created_by: @user
    )

    # Create pending installation service on original order
    original_service = Service.create!(
      order: original_order,
      service_name: "Original Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 5,
      unit_price: 100,
      nrcs: 1000,
      annual_escalator: 0,
      status: "pending_installation"
    )

    de_book_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-DEBOOK",
      sold_date: Date.current,
      order_type: "de_book",
      original_order: original_order,
      created_by: @user
    )

    # Test positive units should fail
    de_book_service = Service.new(
      order: de_book_order,
      service_name: "De-book Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 2, # Positive units should fail
      unit_price: 100,
      nrcs: 500, # Positive NRCs should fail
      annual_escalator: 0,
      status: "canceled"
    )

    assert_not de_book_service.valid?
    assert_includes de_book_service.errors[:units], "must be negative for de-book orders"
    assert_includes de_book_service.errors[:nrcs], "must be negative for de-book orders"
  end

  test "should accept negative values for de-book orders" do
    de_book_customer = Customer.create!(
      customer_id: "CUST002B",
      name: "De-book Customer B"
    )

    original_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-ORIGB",
      sold_date: 30.days.ago,
      order_type: "new_order",
      created_by: @user
    )

    Service.create!(
      order: original_order,
      service_name: "Original Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 5,
      unit_price: 100,
      nrcs: 1000,
      annual_escalator: 0,
      status: "pending_installation"
    )

    de_book_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-DEBOOKB",
      sold_date: Date.current,
      order_type: "de_book",
      original_order: original_order,
      created_by: @user
    )

    de_book_service = Service.new(
      order: de_book_order,
      service_name: "De-book Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: -2,
      unit_price: 100,
      nrcs: -500,
      annual_escalator: 0,
      status: "canceled"
    )

    assert_predicate de_book_service, :valid?
  end

  test "should validate de-book quantities do not exceed pending units" do
    de_book_customer = Customer.create!(
      customer_id: "CUST003",
      name: "De-book Quantity Customer"
    )

    original_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-ORIG2",
      sold_date: 30.days.ago,
      order_type: "new_order",
      created_by: @user
    )

    # Create pending installation service with 3 units
    Service.create!(
      order: original_order,
      service_name: "Original Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 3,
      unit_price: 100,
      nrcs: 1000,
      annual_escalator: 0,
      status: "pending_installation"
    )

    de_book_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-DEBOOK2",
      sold_date: Date.current,
      order_type: "de_book",
      original_order: original_order,
      created_by: @user
    )

    # Try to de-book more units than available
    de_book_service = Service.new(
      order: de_book_order,
      service_name: "De-book Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: -5, # Trying to de-book 5 when only 3 available
      unit_price: 100,
      nrcs: -500,
      annual_escalator: 0,
      status: "canceled"
    )

    assert_not de_book_service.valid?
    assert_includes de_book_service.errors[:units], "cannot exceed available pending units (3 remaining)"
  end

  test "should validate de-book service type exists in pending state" do
    de_book_customer = Customer.create!(
      customer_id: "CUST004",
      name: "De-book Type Customer"
    )

    original_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-ORIG3",
      sold_date: 30.days.ago,
      order_type: "new_order",
      created_by: @user
    )

    # Create pending installation service with internet type only
    Service.create!(
      order: original_order,
      service_name: "Original Internet Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 3,
      unit_price: 100,
      nrcs: 1000,
      annual_escalator: 0,
      status: "pending_installation"
    )

    de_book_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-DEBOOK3",
      sold_date: Date.current,
      order_type: "de_book",
      original_order: original_order,
      created_by: @user
    )

    # Try to de-book voice service type that doesn't exist
    de_book_service = Service.new(
      order: de_book_order,
      service_name: "De-book Voice Service",
      service_type: "voice", # This type doesn't exist in pending state
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: -1,
      unit_price: 100,
      nrcs: -500,
      annual_escalator: 0,
      status: "canceled"
    )

    assert_not de_book_service.valid?
    assert_includes de_book_service.errors[:service_type], "does not exist in pending state on the original order"
  end

  test "should allow positive units for non-de-book orders" do
    # Regular order should require positive units
    @service.units = -1

    assert_not @service.valid?
    assert_includes @service.errors[:units], "must be greater than 0"

    @service.units = 1

    assert_predicate @service, :valid?
  end

  # Tests for sync_as_delivered_with_as_sold callback
  test "should have nil as_delivered fields before save on new record" do
    new_service = Service.new(
      order: @order,
      service_name: "New Service",
      service_type: "internet",
      term_months_as_sold: 24,
      billing_start_date_as_sold: Date.current + 10.days,
      billing_end_date_as_sold: Date.current + 10.days + 24.months - 1.day,
      rev_rec_start_date_as_sold: Date.current + 5.days,
      rev_rec_end_date_as_sold: Date.current + 5.days + 24.months - 1.day,
      units: 2,
      unit_price: 200,
      nrcs: 100,
      annual_escalator: 5,
      status: "pending_installation"
    )

    # Before save, as_delivered fields should be nil
    assert_nil new_service.term_months_as_delivered
    assert_nil new_service.billing_start_date_as_delivered
    assert_nil new_service.billing_end_date_as_delivered
  end

  test "should sync date fields from as_sold to as_delivered on new record" do
    new_service = Service.new(
      order: @order,
      service_name: "New Service",
      service_type: "internet",
      term_months_as_sold: 24,
      billing_start_date_as_sold: Date.current + 10.days,
      billing_end_date_as_sold: Date.current + 10.days + 24.months - 1.day,
      rev_rec_start_date_as_sold: Date.current + 5.days,
      rev_rec_end_date_as_sold: Date.current + 5.days + 24.months - 1.day,
      units: 2,
      unit_price: 200,
      nrcs: 100,
      annual_escalator: 5,
      status: "pending_installation"
    )

    new_service.save!

    # After save, date fields should match
    assert_equal new_service.billing_start_date_as_sold, new_service.billing_start_date_as_delivered
    assert_equal new_service.billing_end_date_as_sold, new_service.billing_end_date_as_delivered
    assert_equal new_service.rev_rec_start_date_as_sold, new_service.rev_rec_start_date_as_delivered
  end

  test "should sync term and rev rec dates from as_sold to as_delivered on new record" do
    new_service = Service.new(
      order: @order,
      service_name: "New Service",
      service_type: "internet",
      term_months_as_sold: 24,
      billing_start_date_as_sold: Date.current + 10.days,
      billing_end_date_as_sold: Date.current + 10.days + 24.months - 1.day,
      rev_rec_start_date_as_sold: Date.current + 5.days,
      rev_rec_end_date_as_sold: Date.current + 5.days + 24.months - 1.day,
      units: 2,
      unit_price: 200,
      nrcs: 100,
      annual_escalator: 5,
      status: "pending_installation"
    )

    new_service.save!

    # After save, term and remaining dates should match
    assert_equal new_service.term_months_as_sold, new_service.term_months_as_delivered
    assert_equal new_service.rev_rec_end_date_as_sold, new_service.rev_rec_end_date_as_delivered
  end

  test "should not sync as_delivered fields on existing record" do
    @service.save!

    # Modify as_delivered fields
    @service.term_months_as_delivered = 18
    @service.billing_end_date_as_delivered = @service.billing_start_date_as_delivered + 18.months - 1.day
    @service.rev_rec_end_date_as_delivered = @service.rev_rec_start_date_as_delivered + 18.months - 1.day

    # Change as_sold fields (but keep them valid)
    @service.term_months_as_sold = 24
    @service.billing_end_date_as_sold = @service.billing_start_date_as_sold + 24.months - 1.day
    @service.rev_rec_end_date_as_sold = @service.rev_rec_start_date_as_sold + 24.months - 1.day
    @service.save!

    # as_delivered should not change
    assert_equal 18, @service.term_months_as_delivered
    assert_not_equal @service.term_months_as_sold, @service.term_months_as_delivered
  end

  # Tests for validation of as_delivered dates
  test "should validate as_delivered billing dates" do
    @service.billing_start_date_as_delivered = Date.current
    @service.billing_end_date_as_delivered = Date.current - 1.day

    assert_not @service.valid?
    assert_includes @service.errors[:billing_end_date_as_delivered], "must be after billing start date"
  end

  test "should validate as_delivered revenue recognition dates" do
    @service.rev_rec_start_date_as_delivered = Date.current
    @service.rev_rec_end_date_as_delivered = Date.current - 1.day

    assert_not @service.valid?
    assert_includes @service.errors[:rev_rec_end_date_as_delivered], "must be after revenue recognition start date"
  end

  test "should validate as_delivered term matches billing dates" do
    @service.term_months_as_delivered = 24
    @service.billing_start_date_as_delivered = Date.current
    @service.billing_end_date_as_delivered = Date.current + 12.months - 1.day

    assert_not @service.valid?
    assert_includes @service.errors[:term_months_as_delivered], "doesn't match the as_delivered billing date range"
  end

  test "should calculate as_delivered end dates from term if missing" do
    service = Service.new(
      order: @order,
      service_name: "Test",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      term_months_as_delivered: 18,
      billing_start_date_as_delivered: Date.current + 1.month,
      rev_rec_start_date_as_delivered: Date.current + 2.months,
      units: 1,
      unit_price: 100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.valid?

    assert_equal Date.current + 1.month + 18.months - 1.day, service.billing_end_date_as_delivered
    assert_equal Date.current + 2.months + 18.months - 1.day, service.rev_rec_end_date_as_delivered
  end

  # Test edge cases
  test "should handle expiring_soon? when billing_end_date_as_delivered is nil" do
    @service.billing_end_date_as_delivered = nil

    assert_not @service.expiring_soon?
  end

  test "should handle days_remaining when billing_end_date_as_delivered is nil" do
    @service.billing_end_date_as_delivered = nil

    assert_equal 0, @service.days_remaining
  end

  test "should validate term matches billing dates with acceptable variance" do
    # Test date within acceptable range (1 day variance)
    @service.billing_end_date_as_sold = @service.billing_start_date_as_sold + @service.term_months_as_sold.months

    assert_predicate @service, :valid?
  end

  test "should handle revenue calculator caching" do
    @service.save!

    calculator1 = @service.revenue_calculator
    calculator2 = @service.revenue_calculator

    # Should return the same cached instance
    assert_same calculator1, calculator2
  end

  test "should handle multiple de-book orders against same original order" do
    de_book_customer = Customer.create!(
      customer_id: "CUST005",
      name: "Multi De-book Customer"
    )

    original_order = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-ORIG4",
      sold_date: 30.days.ago,
      order_type: "new_order",
      created_by: @user
    )

    # Create pending installation service with 10 units
    Service.create!(
      order: original_order,
      service_name: "Original Service",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 10,
      unit_price: 100,
      nrcs: 1000,
      annual_escalator: 0,
      status: "pending_installation"
    )

    # First de-book order for 3 units
    de_book_order1 = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-DEBOOK4A",
      sold_date: Date.current - 1.day,
      order_type: "de_book",
      original_order: original_order,
      created_by: @user
    )

    de_book_service1 = Service.create!(
      order: de_book_order1,
      service_name: "De-book Service 1",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: -3,
      unit_price: 100,
      nrcs: -300,
      annual_escalator: 0,
      status: "canceled"
    )

    # Second de-book order - should only allow 7 more units
    de_book_order2 = Order.create!(
      customer: de_book_customer,
      order_number: "ORD-DEBOOK4B",
      sold_date: Date.current,
      order_type: "de_book",
      original_order: original_order,
      created_by: @user
    )

    # Try to de-book 8 units (should fail)
    de_book_service2 = Service.new(
      order: de_book_order2,
      service_name: "De-book Service 2",
      service_type: "internet",
      term_months_as_sold: 12,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: -8,
      unit_price: 100,
      nrcs: -800,
      annual_escalator: 0,
      status: "canceled"
    )

    assert_not de_book_service2.valid?
    assert_includes de_book_service2.errors[:units], "cannot exceed available pending units (7 remaining)"

    # De-book exactly 7 units (should pass)
    de_book_service2.units = -7
    de_book_service2.nrcs = -700

    assert_predicate de_book_service2, :valid?
  end
end
