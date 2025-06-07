# Service object for calculating revenue metrics for services
#
# Handles complex revenue calculations including:
# - Total Contract Value (TCV) with annual escalators
# - Monthly Recurring Revenue (MRR) and Annual Recurring Revenue (ARR)
# - GAAP MRR calculations
# - Monthly revenue breakdowns
# - Net new value calculations for renewals/upgrades
class RevenueCalculator
  attr_reader :service, :errors

  def initialize(service)
    @service = service
    @errors = []
  end

  # Calculates all revenue metrics for the service
  #
  # Returns Hash with :tcv, :mrr, :arr, :gaap_mrr, and :monthly_values
  def calculate_all
    {
      tcv: calculate_tcv,
      mrr: calculate_mrr,
      arr: calculate_arr,
      gaap_mrr: calculate_gaap_mrr,
      monthly_values: calculate_monthly_breakdown,
    }
  end

  # Calculates Total Contract Value including NRCs and annual escalations
  #
  # Annual escalations are applied at the start of each contract year
  # Returns Float representing the total value of the contract
  def calculate_tcv
    return 0 unless valid_for_calculation?

    # TCV calculation with ANNUAL escalation
    # Escalation applies once per year, not monthly

    base_mrr = service.mrr || 0
    annual_escalator = (service.annual_escalator || 0) / 100.0
    months = service.term_months || 0
    nrcs = service.nrcs || 0

    total_revenue = 0
    current_mrr = base_mrr

    # Calculate revenue year by year
    (1..months).each do |month|
      # Apply escalation at the start of each new year (months 13, 25, 37, etc.)
      current_mrr = current_mrr * (1 + annual_escalator) if month > 1 && ((month - 1) % 12).zero?
      total_revenue += current_mrr
    end

    total_revenue + nrcs
  end

  # Returns the Monthly Recurring Revenue for the service
  #
  # Returns Float representing the base MRR (without escalations)
  def calculate_mrr
    service.mrr || 0
  end

  # Calculates Annual Recurring Revenue
  #
  # Returns Float representing MRR * 12
  def calculate_arr
    calculate_mrr * 12
  end

  # Calculates GAAP Monthly Recurring Revenue
  #
  # GAAP MRR = (TCV - NRCs) / contract term in months
  # Returns Float representing the average monthly revenue for accounting
  def calculate_gaap_mrr
    return 0 unless valid_for_calculation?

    # GAAP MRR = (TCV - NRCs) / contract term in months
    tcv = calculate_tcv
    nrcs = service.nrcs || 0
    months = service.term_months || 0

    return 0 if months.zero?

    (tcv - nrcs) / months
  end

  # Generates a month-by-month revenue breakdown
  #
  # Returns Array of Hashes with :month, :mrr, :arr, and :gaap_mrr for each month
  def calculate_monthly_breakdown
    return [] unless valid_for_calculation?

    breakdown = []
    base_mrr = service.mrr || 0
    annual_escalator = (service.annual_escalator || 0) / 100.0
    current_mrr = base_mrr
    gaap_mrr = calculate_gaap_mrr

    start_date = service.rev_rec_start_date || service.billing_start_date
    end_date = service.rev_rec_end_date || service.billing_end_date

    return [] unless start_date && end_date

    current_date = start_date
    month_number = 1

    while current_date <= end_date
      # Apply escalation at the start of each new year (months 13, 25, 37, etc.)
      current_mrr = current_mrr * (1 + annual_escalator) if month_number > 1 && ((month_number - 1) % 12).zero?

      breakdown << {
        month: current_date.strftime("%Y-%m"),
        mrr: current_mrr.round(2),
        arr: (current_mrr * 12).round(2),
        gaap_mrr: gaap_mrr.round(2), # GAAP MRR is constant throughout the term
      }

      current_date = current_date.next_month
      month_number += 1
    end

    breakdown
  end

  # Calculates the net new value compared to an original service
  #
  # Used for renewals, upgrades, and downgrades to show incremental value
  # Returns Float representing the difference in TCV
  def calculate_net_new_value(original_service)
    return calculate_tcv unless original_service

    current_tcv = calculate_tcv
    original_calculator = self.class.new(original_service)
    original_tcv = original_calculator.calculate_tcv

    current_tcv - original_tcv
  end

  # Calculates prorated MRR for partial first month
  #
  # Returns Float representing the prorated amount based on days remaining
  def prorate_for_partial_month
    return 0 unless service.billing_start_date && service.billing_end_date

    start_date = service.billing_start_date
    days_in_month = Time.days_in_month(start_date.month, start_date.year)
    days_remaining = days_in_month - start_date.day + 1

    # Prorate first month's MRR
    (service.mrr || 0) * days_remaining / days_in_month
  end

  # Calculates monthly invoices for the service with calendar month proration
  #
  # This method generates invoices for each calendar month in the service period,
  # handling partial months at the start and end of the service with proper proration.
  # It also applies annual escalations at the appropriate times.
  #
  # Returns Array of Hashes with invoice details for each month:
  #   - :year - Calendar year
  #   - :month - Calendar month number (1-12)
  #   - :month_name - Full month name (e.g., "January")
  #   - :billing_start - Start date for billing in this month
  #   - :billing_end - End date for billing in this month
  #   - :days_in_month - Total days in the calendar month
  #   - :days_billed - Actual days billed in this month
  #   - :mrr_rate - The MRR rate for this month (including escalations)
  #   - :invoice_amount - Prorated invoice amount for this month
  def calculate_monthly_invoices
    return [] unless valid_for_calculation?

    invoices = []

    # Use billing dates for invoice calculations
    start_date = service.billing_start_date
    end_date = service.billing_end_date

    return [] unless start_date && end_date

    base_mrr = service.mrr || 0
    annual_escalator = (service.annual_escalator || 0) / 100.0

    # Start with the first month of the service
    current_year = start_date.year
    current_month = start_date.month

    # Current MRR rate (will be adjusted with escalations)
    current_mrr_rate = base_mrr

    # Process each calendar month
    while Date.new(current_year, current_month, 1) <= end_date
      month_start = Date.new(current_year, current_month, 1)
      days_in_month = Time.days_in_month(current_month, current_year)
      month_end = Date.new(current_year, current_month, days_in_month)

      # Determine the billing period for this month
      billing_start = [ start_date, month_start ].max
      billing_end = [ end_date, month_end ].min

      # Only process if there are billable days in this month
      if billing_start <= billing_end
        days_billed = (billing_end - billing_start).to_i + 1

        # Calculate the prorated invoice amount
        invoice_amount = (current_mrr_rate * days_billed / days_in_month.to_f).round(2)

        invoices << {
          year: current_year,
          month: current_month,
          month_name: Date::MONTHNAMES[current_month],
          billing_start: billing_start,
          billing_end: billing_end,
          days_in_month: days_in_month,
          days_billed: days_billed,
          mrr_rate: current_mrr_rate.round(2),
          invoice_amount: invoice_amount,
        }
      end

      # Move to next month
      current_month += 1
      if current_month > 12
        current_month = 1
        current_year += 1
      end

      # Check if we need to apply escalation
      # Calculate how many months have passed since service start
      months_elapsed = ((current_year - start_date.year) * 12 + current_month - start_date.month)

      # Apply escalation at the start of each new service year (months 12, 24, 36, etc.)
      current_mrr_rate = current_mrr_rate * (1 + annual_escalator) if months_elapsed.positive? && (months_elapsed % 12).zero?
    end

    invoices
  end

  # Calculates the total invoiced amount across all monthly invoices
  #
  # Returns Float representing the sum of all monthly invoice amounts
  def calculate_total_invoiced
    calculate_monthly_invoices.sum { |invoice| invoice[:invoice_amount] }
  end

  # Calculates billing periods for each calendar month in the service period
  #
  # This method breaks down a service period into calendar month segments,
  # calculating the actual billing days for each month. It handles partial
  # months at the beginning and end of the service period.
  #
  # Returns Array of Hashes with billing period details for each month:
  #   - :year - Calendar year
  #   - :month - Calendar month number (1-12)
  #   - :month_name - Full month name (e.g., "January")
  #   - :billing_start - Start date for billing in this month
  #   - :billing_end - End date for billing in this month
  #   - :days_in_month - Total days in the calendar month
  #   - :days_billed - Actual days billed in this month
  #   - :proration_factor - Decimal factor for proration (days_billed / days_in_month)
  def calculate_billing_periods
    return [] unless service&.billing_start_date && service&.billing_end_date

    periods = []
    start_date = service.billing_start_date
    end_date = service.billing_end_date

    # Start with the first month of the service
    current_year = start_date.year
    current_month = start_date.month

    # Process each calendar month
    while Date.new(current_year, current_month, 1) <= end_date
      month_start = Date.new(current_year, current_month, 1)
      days_in_month = Time.days_in_month(current_month, current_year)
      month_end = Date.new(current_year, current_month, days_in_month)

      # Determine the billing period for this month
      billing_start = [ start_date, month_start ].max
      billing_end = [ end_date, month_end ].min

      # Only include months where there are billable days
      if billing_start <= billing_end
        days_billed = (billing_end - billing_start).to_i + 1
        proration_factor = days_billed / days_in_month.to_f

        periods << {
          year: current_year,
          month: current_month,
          month_name: Date::MONTHNAMES[current_month],
          billing_start: billing_start,
          billing_end: billing_end,
          days_in_month: days_in_month,
          days_billed: days_billed,
          proration_factor: proration_factor.round(6),
        }
      end

      # Move to next month
      current_month += 1
      if current_month > 12
        current_month = 1
        current_year += 1
      end
    end

    periods
  end

  private

  def valid_for_calculation?
    validate_service
    @errors.empty?
  end

  def validate_service
    @errors = []

    @errors << "Service is required" unless service
    return unless service

    @errors << "MRR is required" unless service.mrr && service.mrr >= 0
    @errors << "Term months is required" unless service.term_months && service.term_months.positive?

    if service.billing_start_date && service.billing_end_date
      @errors << "End date must be after or equal to start date" if service.billing_end_date < service.billing_start_date
    end

    return unless service.annual_escalator && (service.annual_escalator.negative? || service.annual_escalator > 100)
      @errors << "Annual escalator must be between 0 and 100"
  end
end
