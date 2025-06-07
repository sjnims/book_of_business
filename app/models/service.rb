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
  validates :units, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :nrcs, numericality: { greater_than_or_equal_to: 0 }
  validates :annual_escalator, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :end_dates_after_start_dates
  validate :term_matches_billing_dates

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_type, ->(type) { where(service_type: type) }
  scope :expiring_soon, -> { active.where(billing_end_date: Date.current..30.days.from_now) }
  scope :expired, -> { where("billing_end_date < ?", Date.current) }

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
