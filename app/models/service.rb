# Represents individual services within an order
#
# Services track the specific products sold to customers including:
# - Pricing details (units, unit price, NRCs)
# - Contract terms and dates
# - Revenue calculations with annual escalators
# - Service lifecycle status
#
# Key calculations include MRR with escalations, TCV, and ARR
class Service < ApplicationRecord
  include Auditable

  # Associations
  belongs_to :order
  has_one :customer, through: :order

  # Service statuses
  STATUSES = %w[pending_installation active extended renewed canceled].freeze

  # Service types
  SERVICE_TYPES = %w[internet voice data cloud managed_services equipment other].freeze

  # Validations
  validates :service_name, presence: true
  validates :service_type, inclusion: { in: SERVICE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :term_months, numericality: { greater_than: 0, only_integer: true }
  validates :billing_start_date, presence: true
  validates :rev_rec_start_date, presence: true
  validates :units, numericality: true
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :nrcs, numericality: true
  validates :annual_escalator, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :end_dates_after_start_dates
  validate :term_matches_billing_dates
  validate :units_sign_validation
  validate :de_book_quantities_validation

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_type, ->(type) { where(service_type: type) }
  scope :expiring_soon, -> { active.where(billing_end_date: Date.current..30.days.from_now) }
  scope :expired, -> { where("billing_end_date < ?", Date.current) }
  scope :needs_extension, -> { active.where("billing_end_date < ?", Date.current) }

  # Callbacks
  before_validation :calculate_end_dates_from_term
  before_save :calculate_revenue_fields

  # Audit configuration - track all service changes
  audit_exclude :created_at, :updated_at

  # Instance methods

  # Returns a formatted display name combining service name and type
  #
  # Returns String in format "Service Name (service_type)"
  def display_name
    "#{service_name} (#{service_type})"
  end

  # Checks if the service is currently active
  #
  # Returns true if status is "active", false otherwise
  def active?
    status == "active"
  end

  # Checks if the service has expired based on billing end date
  #
  # Returns true if billing_end_date is before current date, false otherwise
  def expired?
    billing_end_date < Date.current
  end

  # Status transition methods

  # Activates a pending installation service
  #
  # Returns true if transition successful, false otherwise
  def activate!
    return false unless can_activate?

    update(status: "active")
  end

  # Cancels a service
  #
  # Returns true if transition successful, false otherwise
  def cancel!
    return false unless can_cancel?

    update(status: "canceled")
  end

  # Marks a service as renewed (typically when a renewal order is created)
  #
  # Returns true if transition successful, false otherwise
  def renew!
    return false unless can_renew?

    update(status: "renewed")
  end

  # Updates service to extended status if past contract end date
  # This should be called by background jobs, not manually
  #
  # Returns true if status was updated, false otherwise
  def update_extended_status!
    return false unless should_be_extended?

    update(status: "extended")
  end

  # Status transition checks

  # Checks if the service can be activated
  #
  # Returns true if status is pending_installation, false otherwise
  def can_activate?
    status == "pending_installation"
  end

  # Checks if the service can be canceled
  #
  # Returns true if status is pending_installation or active, false otherwise
  def can_cancel?
    [ "pending_installation", "active" ].include?(status)
  end

  # Checks if the service can be renewed
  #
  # Returns true if status is active or extended, false otherwise
  def can_renew?
    [ "active", "extended" ].include?(status)
  end

  # Checks if the service should be automatically marked as extended
  #
  # Returns true if status is active and past billing end date
  def should_be_extended?
    status == "active" && billing_end_date < Date.current
  end

  # Checks if the service is active and expiring within 30 days
  #
  # Returns true if active and billing_end_date is within next 30 days, false otherwise
  def expiring_soon?
    active? && billing_end_date.between?(Date.current, 30.days.from_now)
  end

  # Calculates the number of days until service billing expiration
  #
  # Returns Integer number of days (negative if already expired)
  def days_remaining
    (billing_end_date - Date.current).to_i
  end

  # Calculates the base monthly recurring charge before escalations
  #
  # Returns the product of units and unit_price
  def monthly_recurring_charge
    units * unit_price
  end

  # Returns the revenue calculator instance for this service
  #
  # Returns RevenueCalculator instance
  def revenue_calculator
    @revenue_calculator ||= RevenueCalculator.new(self)
  end

  # Calculates all revenue metrics using the RevenueCalculator
  #
  # Returns Hash with :tcv, :mrr, :arr, :gaap_mrr, :monthly_values
  def calculate_all_revenues
    revenue_calculator.calculate_all
  end

  # Calculates the Total Contract Value using the RevenueCalculator
  #
  # Returns Float representing total contract value including NRCs and escalations
  def calculate_tcv
    revenue_calculator.calculate_tcv
  end

  # Calculates the GAAP Monthly Recurring Revenue
  #
  # Returns Float representing (TCV - NRCs) / term_months
  def calculate_gaap_mrr
    revenue_calculator.calculate_gaap_mrr
  end

  # Calculates net new value compared to an original service (for renewals/upgrades)
  #
  # Returns Float representing the difference in TCV
  def calculate_net_new_value(original_service = nil)
    revenue_calculator.calculate_net_new_value(original_service)
  end

  # Gets the monthly revenue breakdown with escalations
  #
  # Returns Array of hashes with monthly revenue details
  def monthly_revenue_breakdown
    revenue_calculator.calculate_monthly_breakdown
  end

  private

  def end_dates_after_start_dates
    # Validate billing dates
    errors.add(:billing_end_date, "must be after billing start date") if billing_start_date && billing_end_date && billing_end_date <= billing_start_date

    # Validate revenue recognition dates
    return unless rev_rec_start_date && rev_rec_end_date && rev_rec_end_date <= rev_rec_start_date

    errors.add(:rev_rec_end_date, "must be after revenue recognition start date")
  end

  def term_matches_billing_dates
    return unless billing_start_date && billing_end_date && term_months

    # Calculate the expected end date based on term_months
    expected_end_date = billing_start_date + term_months.months - 1.day

    # Allow for minor date variations (e.g., month-end differences)
    return if billing_end_date >= expected_end_date - 1.day && billing_end_date <= expected_end_date + 1.day

    errors.add(:term_months, "doesn't match the billing date range")
  end

  def units_sign_validation
    return unless units.present? || nrcs.present?

    if order&.is_de_book?
      # De-book order services should have negative values
      errors.add(:units, "must be negative for de-book orders") if units.present? && units.positive?
      errors.add(:nrcs, "must be negative for de-book orders") if nrcs.present? && nrcs.positive?
    else
      # All other order services should have positive units
      errors.add(:units, "must be greater than 0") if units.present? && units <= 0
      errors.add(:nrcs, "must be greater than or equal to 0") if nrcs.present? && nrcs.negative?
    end
  end

  def de_book_quantities_validation
    return unless order&.is_de_book? && order.original_order.present?

    # For de-book orders, validate that we're not de-booking more than what's pending
    original_order = order.original_order

    # Group services by type to check quantities
    original_pending_services = original_order.services
      .where(status: "pending_installation")
      .group_by(&:service_type)

    # Check if this service type exists in pending state
    if service_type.present? && !original_pending_services[service_type]
      errors.add(:service_type, "does not exist in pending state on the original order")
      return
    end

    # Calculate total pending units for this service type
    return unless service_type.present? && units.present?
      pending_units = original_pending_services[service_type]&.sum(&:units) || 0

      # Sum up any other de-book orders against this original order
      existing_de_booked_units = original_order.renewal_orders
        .where(order_type: "de_book")
        .where.not(id: order.id)
        .joins(:services)
        .where(services: { service_type: service_type })
        .sum("ABS(services.units)")

      available_units = pending_units - existing_de_booked_units

      return unless units.abs > available_units
        errors.add(:units, "cannot exceed available pending units (#{available_units.to_i} remaining)")
  end

  def calculate_end_dates_from_term
    # Calculate billing end date if not provided
    self.billing_end_date = billing_start_date + term_months.months - 1.day if billing_start_date.present? && term_months.present? && billing_end_date.blank?

    # Calculate rev rec end date if not provided
    return unless rev_rec_start_date.present? && term_months.present? && rev_rec_end_date.blank?

    self.rev_rec_end_date = rev_rec_start_date + term_months.months - 1.day
  end

  def calculate_revenue_fields
    # Set base MRR from monthly recurring charge if not already set
    self.mrr ||= monthly_recurring_charge

    # Use revenue calculator for complex calculations
    calculations = revenue_calculator.calculate_all
    self.tcv = calculations[:tcv]
    self.arr = calculations[:arr]
    # Note: We keep the user-entered MRR, but could use GAAP MRR if needed
  end
end
