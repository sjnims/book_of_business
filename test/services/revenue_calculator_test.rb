require "test_helper"

class RevenueCalculatorTest < ActiveSupport::TestCase
  setup do
    @order = orders(:order_one)
    @service = services(:internet_service)
    @calculator = RevenueCalculator.new(@service)
  end

  test "calculate_tcv without escalation" do
    @service.update!(
      mrr: 1000,
      term_months: 12,
      annual_escalator: 0,
      nrcs: 500,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil, # Let model calculate
      rev_rec_start_date: Date.new(2024, 1, 1),
      rev_rec_end_date: nil # Let model calculate
    )

    # TCV = (1000 * 12) + 500 = 12,500
    assert_equal 12_500, @calculator.calculate_tcv
  end

  test "calculate_tcv with annual escalation" do
    @service.update!(
      mrr: 1000,
      term_months: 12,
      annual_escalator: 5,
      nrcs: 0,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil # Let model calculate
    )

    # With 5% annual escalation - no escalation in first year
    # 12 months * $1,000 = $12,000
    tcv = @calculator.calculate_tcv

    assert_equal 12_000, tcv
  end

  test "calculate_tcv with escalation and NRCs" do
    @service.update!(
      mrr: 1000,
      term_months: 24,
      annual_escalator: 3,
      nrcs: 1500,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil # Let model calculate
    )

    tcv = @calculator.calculate_tcv
    # Year 1: 12 * $1,000 = $12,000
    # Year 2: 12 * $1,030 = $12,360
    # Plus NRCs: $1,500
    # Total: $12,000 + $12,360 + $1,500 = $25,860
    assert_equal 25_860, tcv
  end

  test "calculate_mrr returns service MRR" do
    @service.update!(mrr: 2500)

    assert_equal 2500, @calculator.calculate_mrr
  end

  test "calculate_arr returns annual recurring revenue" do
    @service.update!(mrr: 2500)

    assert_equal 30_000, @calculator.calculate_arr
  end

  test "calculate_gaap_mrr" do
    @service.update!(
      mrr: 1000,
      term_months: 12,
      annual_escalator: 0,
      nrcs: 1200,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil # Let model calculate
    )

    # GAAP MRR = (TCV - NRCs) / months
    # (12,000 + 1,200 - 1,200) / 12 = 1,000
    assert_equal 1000, @calculator.calculate_gaap_mrr
  end

  test "calculate_gaap_mrr with escalation" do
    @service.update!(
      mrr: 1000,
      term_months: 36,
      annual_escalator: 3,
      nrcs: 0,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil # Let model calculate
    )

    gaap_mrr = @calculator.calculate_gaap_mrr
    # Year 1: 12 * $1,000 = $12,000
    # Year 2: 12 * $1,030 = $12,360
    # Year 3: 12 * $1,060.90 = $12,730.80
    # TCV: $37,090.80 / 36 months = $1,030.30
    assert_in_delta 1030.30, gaap_mrr, 0.01
  end

  test "calculate_monthly_breakdown returns correct length" do
    @service.update!(
      mrr: 1000,
      term_months: 24,
      annual_escalator: 3,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil, # Let model calculate
      rev_rec_start_date: Date.new(2024, 1, 1),
      rev_rec_end_date: nil # Let model calculate
    )

    breakdown = @calculator.calculate_monthly_breakdown

    assert_equal 24, breakdown.length
  end

  test "calculate_monthly_breakdown applies annual escalation correctly" do
    @service.update!(
      mrr: 1000,
      term_months: 24,
      annual_escalator: 3,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil, # Let model calculate
      rev_rec_start_date: Date.new(2024, 1, 1),
      rev_rec_end_date: nil # Let model calculate
    )

    breakdown = @calculator.calculate_monthly_breakdown

    # Check first and last month of each year
    assert_in_delta(1000.0, breakdown[0][:mrr])
    assert_in_delta(1030.0, breakdown[12][:mrr])
  end

  test "calculate_net_new_value for new service" do
    @service.update!(
      mrr: 1000,
      term_months: 12,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil # Let model calculate
    )

    net_new = @calculator.calculate_net_new_value(nil)

    assert_equal @calculator.calculate_tcv, net_new
  end

  test "calculate_net_new_value for upgrade" do
    # Create a new service for the original
    original_service = Service.create!(
      order: orders(:order_one),
      service_name: "Original Service",
      service_type: "internet",
      mrr: 800,
      units: 1,
      unit_price: 800,
      term_months: 12,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date: Date.new(2024, 1, 1),
      rev_rec_start_date: Date.new(2024, 1, 1),
      status: "active"
    )

    # Create a new service for the upgrade
    upgraded_service = Service.create!(
      order: orders(:order_two),
      service_name: "Upgraded Service",
      service_type: "internet",
      mrr: 1200,
      units: 1,
      unit_price: 1200,
      term_months: 12,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date: Date.new(2024, 1, 1),
      rev_rec_start_date: Date.new(2024, 1, 1),
      status: "active"
    )

    calculator = RevenueCalculator.new(upgraded_service)
    net_new = calculator.calculate_net_new_value(original_service)

    # Net new should be 400 * 12 = 4,800
    assert_equal 4_800, net_new
  end

  test "calculate_net_new_value for downgrade shows negative" do
    # Create a new service for the original
    original_service = Service.create!(
      order: orders(:order_one),
      service_name: "Original Service",
      service_type: "internet",
      mrr: 1200,
      units: 1,
      unit_price: 1200,
      term_months: 12,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date: Date.new(2024, 1, 1),
      rev_rec_start_date: Date.new(2024, 1, 1),
      status: "active"
    )

    # Create a new service for the downgrade
    downgraded_service = Service.create!(
      order: orders(:order_two),
      service_name: "Downgraded Service",
      service_type: "internet",
      mrr: 800,
      units: 1,
      unit_price: 800,
      term_months: 12,
      nrcs: 0,
      annual_escalator: 0,
      billing_start_date: Date.new(2024, 1, 1),
      rev_rec_start_date: Date.new(2024, 1, 1),
      status: "active"
    )

    calculator = RevenueCalculator.new(downgraded_service)
    net_new = calculator.calculate_net_new_value(original_service)

    # Net new should be -400 * 12 = -4,800
    assert_equal(-4_800, net_new)
  end

  test "prorate_for_partial_month" do
    # Service starting on the 15th of a 30-day month
    @service.update!(
      mrr: 3000,
      billing_start_date: Date.new(2024, 4, 15), # April has 30 days
      billing_end_date: Date.new(2024, 5, 14),
      term_months: 1
    )

    # Days remaining: 16 (15th through 30th)
    # Prorated: 3000 * 16 / 30 = 1,600
    assert_equal 1_600, @calculator.prorate_for_partial_month
  end

  test "prorate_for_partial_month in February" do
    # Test leap year proration
    @service.update!(
      mrr: 2900,
      billing_start_date: Date.new(2024, 2, 15), # 2024 is a leap year
      billing_end_date: Date.new(2024, 3, 14),
      term_months: 1
    )

    # Days remaining: 15 (15th through 29th in leap year)
    # Prorated: 2900 * 15 / 29 = 1,500
    assert_equal 1_500, @calculator.prorate_for_partial_month
  end

  test "validates service presence" do
    calculator = RevenueCalculator.new(nil)
    calculator.calculate_tcv

    assert_includes calculator.errors, "Service is required"
  end

  test "validates MRR presence" do
    @service.update_columns(mrr: nil) # Use update_columns to skip validations
    @calculator = RevenueCalculator.new(@service) # Reinitialize calculator
    @calculator.calculate_tcv

    assert_includes @calculator.errors, "MRR is required"
  end

  test "validates term months presence" do
    @service.update_columns(term_months: nil) # Use update_columns to skip validations
    @calculator = RevenueCalculator.new(@service) # Reinitialize calculator
    @calculator.calculate_tcv

    assert_includes @calculator.errors, "Term months is required"
  end

  test "validates date logic" do
    @service.update_columns(
      billing_start_date: Date.new(2024, 2, 1),
      billing_end_date: Date.new(2024, 1, 1)
    )
    @calculator = RevenueCalculator.new(@service) # Reinitialize calculator
    @calculator.calculate_tcv

    assert_includes @calculator.errors, "End date must be after or equal to start date"
  end

  test "validates annual escalator range" do
    @service.update_columns(annual_escalator: 150) # Use update_columns to skip validations
    @calculator = RevenueCalculator.new(@service) # Reinitialize calculator
    @calculator.calculate_tcv

    assert_includes @calculator.errors, "Annual escalator must be between 0 and 100"
  end

  test "handles zero term months gracefully" do
    @service.update_columns(term_months: 0) # Use update_columns to skip validations
    @calculator = RevenueCalculator.new(@service) # Reinitialize calculator

    assert_equal 0, @calculator.calculate_gaap_mrr
  end

  test "edge case: very high escalation rate" do
    @service.update!(
      mrr: 100,
      term_months: 36,
      annual_escalator: 50, # 50% annual escalation
      nrcs: 0,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil # Let model calculate
    )

    tcv = @calculator.calculate_tcv
    # Year 1: 12 * $100 = $1,200
    # Year 2: 12 * $150 = $1,800
    # Year 3: 12 * $225 = $2,700
    # Total: $5,700
    assert_equal 5_700, tcv
  end

  test "edge case: single month term" do
    @service.update!(
      mrr: 5000,
      term_months: 1,
      annual_escalator: 12,
      nrcs: 100,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil # Let model calculate
    )

    assert_equal 5_100, @calculator.calculate_tcv
    assert_equal 5_000, @calculator.calculate_gaap_mrr
  end

  test "handles nil values gracefully" do
    @service.update_columns(
      mrr: 1000,
      term_months: 12,
      annual_escalator: nil,
      nrcs: nil
    )
    @calculator = RevenueCalculator.new(@service) # Reinitialize calculator

    # Should treat nil as 0
    assert_equal 12_000, @calculator.calculate_tcv
  end

  test "calculate_all returns complete hash structure" do
    @service.update!(
      mrr: 1000,
      term_months: 12,
      annual_escalator: 0,
      nrcs: 500,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil, # Let model calculate
      rev_rec_start_date: Date.new(2024, 1, 1),
      rev_rec_end_date: nil # Let model calculate
    )

    result = @calculator.calculate_all

    assert_kind_of Hash, result
    assert result.key?(:tcv)
    assert result.key?(:monthly_values)
  end

  test "calculate_all returns correct values" do
    @service.update!(
      mrr: 1000,
      term_months: 12,
      annual_escalator: 0,
      nrcs: 500,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil, # Let model calculate
      rev_rec_start_date: Date.new(2024, 1, 1),
      rev_rec_end_date: nil # Let model calculate
    )

    result = @calculator.calculate_all

    assert_equal 12_500, result[:tcv]
    assert_equal 1_000, result[:mrr]
    assert_equal 12_000, result[:arr]
  end

  test "validates user example TCV and GAAP MRR calculations" do
    @service.update!(
      mrr: 1000,
      term_months: 36,
      annual_escalator: 3,
      nrcs: 1000,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil, # Let model calculate
      rev_rec_start_date: Date.new(2024, 1, 1),
      rev_rec_end_date: nil # Let model calculate
    )

    # TCV should be $38,090.80
    assert_in_delta 38_090.80, @calculator.calculate_tcv, 0.01

    # GAAP MRR should be $1,030.30
    assert_in_delta 1_030.30, @calculator.calculate_gaap_mrr, 0.01
  end

  test "validates user example monthly escalations" do
    @service.update!(
      mrr: 1000,
      term_months: 36,
      annual_escalator: 3,
      nrcs: 1000,
      billing_start_date: Date.new(2024, 1, 1),
      billing_end_date: nil, # Let model calculate
      rev_rec_start_date: Date.new(2024, 1, 1),
      rev_rec_end_date: nil # Let model calculate
    )

    breakdown = @calculator.calculate_monthly_breakdown

    # Check one month from each year
    assert_in_delta(1_000.00, breakdown[0][:mrr])  # Year 1
    assert_in_delta(1_030.00, breakdown[12][:mrr]) # Year 2
    assert_in_delta 1_060.90, breakdown[24][:mrr], 0.01 # Year 3
  end

  test "should calculate monthly invoices for full months" do
    service = Service.new(
      order: @order,
      service_name: "Monthly Invoice Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 3, 31),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 3, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices

    assert_equal 3, invoices.length
  end

  test "should calculate correct details for January full month invoice" do
    service = Service.new(
      order: @order,
      service_name: "Monthly Invoice Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 3, 31),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 3, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices
    january = invoices[0]

    assert_equal "January", january[:month_name]
    assert_equal 31, january[:days_billed]
    assert_in_delta 1000.00, january[:invoice_amount], 0.01
  end

  test "should calculate correct details for February full month invoice" do
    service = Service.new(
      order: @order,
      service_name: "Monthly Invoice Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 3, 31),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 3, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices
    february = invoices[1]

    assert_equal "February", february[:month_name]
    assert_equal 28, february[:days_billed]
    assert_in_delta 1000.00, february[:invoice_amount], 0.01
  end

  test "should calculate correct details for March full month invoice" do
    service = Service.new(
      order: @order,
      service_name: "Monthly Invoice Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 3, 31),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 3, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices
    march = invoices[2]

    assert_equal "March", march[:month_name]
    assert_equal 31, march[:days_billed]
    assert_in_delta 1000.00, march[:invoice_amount], 0.01
  end

  test "should calculate monthly invoices with partial first and last months" do
    service = Service.new(
      order: @order,
      service_name: "Partial Month Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 14),
      billing_end_date: Date.new(2025, 4, 13),
      rev_rec_start_date: Date.new(2025, 1, 14),
      rev_rec_end_date: Date.new(2025, 4, 13),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices

    assert_equal 4, invoices.length
  end

  test "should prorate January partial month correctly" do
    service = Service.new(
      order: @order,
      service_name: "Partial Month Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 14),
      billing_end_date: Date.new(2025, 4, 13),
      rev_rec_start_date: Date.new(2025, 1, 14),
      rev_rec_end_date: Date.new(2025, 4, 13),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices
    january = invoices[0]

    # January - partial month (14th to 31st = 18 days)
    assert_equal 18, january[:days_billed]
    assert_in_delta 580.65, january[:invoice_amount], 0.01 # (1000 * 18 / 31)
  end

  test "should bill full months correctly in partial service period" do
    service = Service.new(
      order: @order,
      service_name: "Partial Month Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 14),
      billing_end_date: Date.new(2025, 4, 13),
      rev_rec_start_date: Date.new(2025, 1, 14),
      rev_rec_end_date: Date.new(2025, 4, 13),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices

    # Check February and March are full months
    assert_equal 28, invoices[1][:days_billed]
    assert_equal 31, invoices[2][:days_billed]
  end

  test "should prorate April partial month correctly" do
    service = Service.new(
      order: @order,
      service_name: "Partial Month Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 14),
      billing_end_date: Date.new(2025, 4, 13),
      rev_rec_start_date: Date.new(2025, 1, 14),
      rev_rec_end_date: Date.new(2025, 4, 13),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices
    april = invoices[3]

    # April - partial month (1st to 13th = 13 days)
    assert_equal 13, april[:days_billed]
    assert_in_delta 433.33, april[:invoice_amount], 0.01 # (1000 * 13 / 30)
  end

  test "should apply annual escalation in monthly invoices" do
    service = Service.new(
      order: @order,
      service_name: "Escalating Service",
      service_type: "internet",
      term_months: 24,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2026, 12, 31),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2026, 12, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 10.0, # 10% annual increase
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices

    assert_equal 24, invoices.length

    # First year - all months at $1000
    (0..11).each do |i|
      assert_in_delta 1000.00, invoices[i][:mrr_rate], 0.01
    end

    # Second year - all months at $1100 (10% increase)
    (12..23).each do |i|
      assert_in_delta 1100.00, invoices[i][:mrr_rate], 0.01
    end
  end

  test "should calculate total invoiced amount" do
    service = Service.new(
      order: @order,
      service_name: "Total Invoice Service",
      service_type: "internet",
      term_months: 12,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 12, 31),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 12, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 500, # Note: NRCs are not included in monthly invoices
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    total_invoiced = calculator.calculate_total_invoiced

    # 12 months * $1000 = $12,000 (NRCs are handled separately)
    assert_in_delta 12_000.00, total_invoiced, 0.01
  end

  test "should handle single day service in monthly invoices" do
    # Service that lasts just one day
    service = Service.new(
      order: @order,
      service_name: "Single Day Service",
      service_type: "internet",
      term_months: 1,
      billing_start_date: Date.new(2025, 1, 15),
      billing_end_date: Date.new(2025, 1, 15),
      rev_rec_start_date: Date.new(2025, 1, 15),
      rev_rec_end_date: Date.new(2025, 1, 15),
      units: 1,
      unit_price: 3100, # $100/day * 31 days
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    # Manually set MRR since we're skipping validation
    service.mrr = 3100
    # Allow single-day services by skipping the date validation
    service.save!(validate: false)
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices

    assert_equal 1, invoices.length
    assert_equal 1, invoices[0][:days_billed]
    assert_in_delta 100.00, invoices[0][:invoice_amount] # 3100 * 1 / 31
  end

  test "should handle leap year in monthly invoices" do
    service = Service.new(
      order: @order,
      service_name: "Leap Year Service",
      service_type: "internet",
      term_months: 1,
      billing_start_date: Date.new(2024, 2, 1),
      billing_end_date: Date.new(2024, 2, 29),
      rev_rec_start_date: Date.new(2024, 2, 1),
      rev_rec_end_date: Date.new(2024, 2, 29),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )

    service.save!
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices

    assert_equal 29, invoices[0][:days_in_month] # Leap year February
    assert_equal 29, invoices[0][:days_billed]
    assert_in_delta(1000.00, invoices[0][:invoice_amount])
  end

  test "should handle invalid service for monthly invoices" do
    service = Service.new(
      order: @order,
      service_name: "Invalid Service",
      service_type: "internet",
      term_months: 0, # Invalid
      units: 1,
      unit_price: 1000,
      status: "active"
    )

    # Don't save the invalid service - just test that calculator handles it
    calculator = RevenueCalculator.new(service)
    invoices = calculator.calculate_monthly_invoices

    assert_empty invoices
  end

  test "calculate_billing_periods returns correct number of periods" do
    service = Service.new(
      order: @order,
      service_name: "Billing Period Service",
      service_type: "internet",
      term_months: 3,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 3, 31),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 3, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods

    assert_equal 3, periods.length
  end

  test "calculate_billing_periods handles partial first month - month name and dates" do
    service = Service.new(
      order: @order,
      service_name: "Partial Start Service",
      service_type: "internet",
      term_months: 2,
      billing_start_date: Date.new(2025, 1, 15),
      billing_end_date: Date.new(2025, 3, 14),
      rev_rec_start_date: Date.new(2025, 1, 15),
      rev_rec_end_date: Date.new(2025, 3, 14),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods
    january = periods[0]

    assert_equal "January", january[:month_name]
    assert_equal Date.new(2025, 1, 15), january[:billing_start]
    assert_equal Date.new(2025, 1, 31), january[:billing_end]
  end

  test "calculate_billing_periods handles partial first month - proration" do
    service = Service.new(
      order: @order,
      service_name: "Partial Start Service",
      service_type: "internet",
      term_months: 2,
      billing_start_date: Date.new(2025, 1, 15),
      billing_end_date: Date.new(2025, 3, 14),
      rev_rec_start_date: Date.new(2025, 1, 15),
      rev_rec_end_date: Date.new(2025, 3, 14),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods
    january = periods[0]

    assert_equal 31, january[:days_in_month]
    assert_equal 17, january[:days_billed]
    assert_in_delta 0.548387, january[:proration_factor], 0.000001
  end

  test "calculate_billing_periods handles partial last month - month name and dates" do
    service = Service.new(
      order: @order,
      service_name: "Partial End Service",
      service_type: "internet",
      term_months: 2,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 2, 28),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 2, 28),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods
    february = periods[1]

    assert_equal "February", february[:month_name]
    assert_equal Date.new(2025, 2, 1), february[:billing_start]
    assert_equal Date.new(2025, 2, 28), february[:billing_end]
  end

  test "calculate_billing_periods handles partial last month - proration" do
    service = Service.new(
      order: @order,
      service_name: "Partial End Service",
      service_type: "internet",
      term_months: 2,
      billing_start_date: Date.new(2025, 1, 1),
      billing_end_date: Date.new(2025, 2, 28),
      rev_rec_start_date: Date.new(2025, 1, 1),
      rev_rec_end_date: Date.new(2025, 2, 28),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods
    february = periods[1]

    assert_equal 28, february[:days_in_month]
    assert_equal 28, february[:days_billed]
    assert_in_delta(1.0, february[:proration_factor])
  end

  test "calculate_billing_periods handles single day service" do
    service = Service.new(
      order: @order,
      service_name: "Single Day Service",
      service_type: "internet",
      term_months: 1,
      billing_start_date: Date.new(2025, 1, 15),
      billing_end_date: Date.new(2025, 1, 15),
      rev_rec_start_date: Date.new(2025, 1, 15),
      rev_rec_end_date: Date.new(2025, 1, 15),
      units: 1,
      unit_price: 3100,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.mrr = 3100
    service.save!(validate: false)

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods

    assert_equal 1, periods.length
    period = periods[0]

    assert_equal 1, period[:days_billed]
    assert_in_delta 0.032258, period[:proration_factor], 0.000001
  end

  test "calculate_billing_periods handles leap year" do
    service = Service.new(
      order: @order,
      service_name: "Leap Year Service",
      service_type: "internet",
      term_months: 1,
      billing_start_date: Date.new(2024, 2, 1),
      billing_end_date: Date.new(2024, 2, 29),
      rev_rec_start_date: Date.new(2024, 2, 1),
      rev_rec_end_date: Date.new(2024, 2, 29),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods
    period = periods[0]

    assert_equal 29, period[:days_in_month]
    assert_equal 29, period[:days_billed]
    assert_in_delta(1.0, period[:proration_factor])
  end

  test "calculate_billing_periods returns empty array for nil dates" do
    service = Service.new(
      order: @order,
      service_name: "No Dates Service",
      service_type: "internet",
      term_months: 12,
      units: 1,
      unit_price: 1000,
      status: "active"
    )
    # Don't set billing dates

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods

    assert_empty periods
  end

  test "calculate_billing_periods spans multiple years - count" do
    service = Service.new(
      order: @order,
      service_name: "Multi-Year Service",
      service_type: "internet",
      term_months: 14,
      billing_start_date: Date.new(2024, 12, 1),
      billing_end_date: Date.new(2026, 1, 31),
      rev_rec_start_date: Date.new(2024, 12, 1),
      rev_rec_end_date: Date.new(2026, 1, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods

    assert_equal 14, periods.length
  end

  test "calculate_billing_periods spans multiple years - first period" do
    service = Service.new(
      order: @order,
      service_name: "Multi-Year Service",
      service_type: "internet",
      term_months: 14,
      billing_start_date: Date.new(2024, 12, 1),
      billing_end_date: Date.new(2026, 1, 31),
      rev_rec_start_date: Date.new(2024, 12, 1),
      rev_rec_end_date: Date.new(2026, 1, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods

    # Check first period (Dec 2024)
    assert_equal 2024, periods[0][:year]
    assert_equal 12, periods[0][:month]
  end

  test "calculate_billing_periods spans multiple years - last period" do
    service = Service.new(
      order: @order,
      service_name: "Multi-Year Service",
      service_type: "internet",
      term_months: 14,
      billing_start_date: Date.new(2024, 12, 1),
      billing_end_date: Date.new(2026, 1, 31),
      rev_rec_start_date: Date.new(2024, 12, 1),
      rev_rec_end_date: Date.new(2026, 1, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods

    # Check last period (Jan 2026)
    assert_equal 2026, periods[-1][:year]
    assert_equal 1, periods[-1][:month]
  end

  test "calculate_billing_periods spans multiple years - year transition" do
    service = Service.new(
      order: @order,
      service_name: "Multi-Year Service",
      service_type: "internet",
      term_months: 14,
      billing_start_date: Date.new(2024, 12, 1),
      billing_end_date: Date.new(2026, 1, 31),
      rev_rec_start_date: Date.new(2024, 12, 1),
      rev_rec_end_date: Date.new(2026, 1, 31),
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 0,
      status: "active"
    )
    service.save!

    calculator = RevenueCalculator.new(service)
    periods = calculator.calculate_billing_periods

    # Check transition period (Jan 2025)
    assert_equal 2025, periods[1][:year]
    assert_equal 1, periods[1][:month]
  end
end
