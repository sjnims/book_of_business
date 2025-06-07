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

  # Calculates the Monthly Recurring Revenue for a specific month in the contract term
  # accounting for annual escalation rates
  #
  # Returns 0 if the month_number is invalid (outside the contract term)
  # Returns the escalated MRR value for the specified month
  def calculate_mrr_at_month(month_number)
    return 0 unless month_number.positive? && month_number <= term_months

    base_mrr = monthly_recurring_charge
    years_passed = (month_number - 1) / 12
    escalation_factor = (1 + annual_escalator / 100.0) ** years_passed

    base_mrr * escalation_factor
  end

  # Calculates the Total Contract Value including non-recurring charges and
  # all monthly recurring revenue with escalations over the contract term
  #
  # Returns only NRCs if term_months is zero
  # Returns the sum of NRCs plus all monthly charges with escalations applied
  def calculate_total_tcv
    return nrcs if term_months.zero?

    total = nrcs

    (1..term_months).each do |month|
      total += calculate_mrr_at_month(month)
    end

    total
  end

  # Calculates the average Monthly Recurring Revenue over the contract term
  # taking into account annual escalations
  #
  # Returns 0 if term_months is zero
  # Returns the average MRR across all months including escalations
  def calculate_average_mrr
    return 0 if term_months.zero?

    total_mrr = (1..term_months).sum { |month| calculate_mrr_at_month(month) }
    total_mrr / term_months
  end

  # Calculates the Annual Recurring Revenue based on average MRR
  #
  # Returns the average MRR multiplied by 12 months
  def calculate_arr
    calculate_average_mrr * 12
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

    calculated_months = ((billing_end_date.year * 12 + billing_end_date.month) -
                        (billing_start_date.year * 12 + billing_start_date.month))

    return unless calculated_months != term_months
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
    self.mrr = calculate_average_mrr
    self.arr = calculate_arr
    self.tcv = calculate_total_tcv
  end
end
