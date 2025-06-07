# Represents sales orders containing one or more services
#
# Orders track:
# - Customer relationship and order metadata
# - Order type (new order, renewal, upgrade, downgrade)
# - Aggregated revenue metrics (TCV, MRR, GAAP MRR)
# - Links to original orders for renewal chains
#
# Automatically calculates totals from associated services
class Order < ApplicationRecord
  include Auditable

  # Associations
  belongs_to :customer
  belongs_to :created_by, class_name: "User"
  belongs_to :original_order, class_name: "Order", optional: true
  has_many :renewal_orders, class_name: "Order", foreign_key: "original_order_id",
           dependent: :restrict_with_error, inverse_of: :original_order
  has_many :services, dependent: :destroy

  # Order types
  ORDER_TYPES = %w[new_order renewal upgrade downgrade cancellation de_book].freeze

  # Validations
  validates :order_number, presence: true, uniqueness: { case_sensitive: false }
  validates :sold_date, presence: true
  validates :order_type, inclusion: { in: ORDER_TYPES }
  validates :tcv, numericality: true, allow_nil: true
  validates :baseline_mrr, numericality: true, allow_nil: true
  validates :gaap_mrr, numericality: true, allow_nil: true
  validate :de_book_requires_original_order
  validate :renewal_requires_original_order
  validate :financial_values_sign_validation

  # Scopes
  scope :by_date, -> { order(sold_date: :desc) }
  scope :recent, -> { by_date.limit(10) }
  scope :by_type, ->(type) { where(order_type: type) }
  scope :renewals, -> { where(order_type: "renewal") }
  scope :new_orders, -> { where(order_type: "new_order") }
  scope :in_date_range, ->(start_date, end_date) { where(sold_date: start_date..end_date) }

  # Callbacks
  before_validation :normalize_order_number
  before_save :calculate_totals

  # Audit configuration - track all order changes
  audit_exclude :created_at, :updated_at

  # Nested attributes
  accepts_nested_attributes_for :services, allow_destroy: true

  # Instance methods

  # Returns a formatted display name combining order number and customer name
  #
  # Returns String in format "ORDER_NUMBER - Customer Name"
  def display_name
    "#{order_number} - #{customer.name}"
  end

  # Checks if this order is a renewal order
  #
  # Returns true if order_type is "renewal", false otherwise
  def is_renewal?
    order_type == "renewal"
  end

  # Checks if this order is a new order
  #
  # Returns true if order_type is "new_order", false otherwise
  def is_new_order?
    order_type == "new_order"
  end

  # Checks if this order is a de-book order
  #
  # Returns true if order_type is "de_book", false otherwise
  def is_de_book?
    order_type == "de_book"
  end

  # Checks if the order has any active services
  #
  # Returns true if at least one active service exists, false otherwise
  def has_active_services?
    services.where(status: "active").exists?
  end

  # Returns all services with active status for this order
  #
  # Returns ActiveRecord::Relation of active services
  def active_services
    services.where(status: "active")
  end

  # Returns pending installation services that can be de-booked
  #
  # Returns ActiveRecord::Relation of pending services
  def pending_services
    services.where(status: "pending_installation")
  end

  # Calculates available units for de-booking by service type
  #
  # Returns a hash with service types as keys and available units as values
  def available_for_de_book
    return {} unless pending_services.any?

    # Get pending units by service type
    pending_by_type = pending_services.group(:service_type).sum(:units)

    # Subtract already de-booked units
    de_booked_by_type = renewal_orders
      .where(order_type: "de_book")
      .joins(:services)
      .group("services.service_type")
      .sum("ABS(services.units)")

    # Calculate available units
    result = {}
    pending_by_type.each do |type, units|
      de_booked = de_booked_by_type[type] || 0
      available = units - de_booked
      result[type] = available if available.positive?
    end
    result
  end

  # Calculates total Monthly Recurring Revenue across all services
  #
  # Returns the sum of MRR from all associated services
  def calculate_mrr
    services.sum(:mrr)
  end

  # Calculates total contract value across all services
  #
  # Returns the sum of TCV from all associated services
  def calculate_tcv
    services.sum(:tcv)
  end

  # Calculates GAAP Monthly Recurring Revenue using weighted average term methodology
  # GAAP MRR = (Total Recurring Revenue) / (Weighted Average Term in Months)
  #
  # The weighted average term is calculated by weighting each service's term
  # by its recurring revenue contribution
  #
  # Returns 0 if there are no services or no recurring revenue
  # Returns the GAAP MRR value based on weighted average term
  def calculate_gaap_mrr
    return 0 if services.empty?

    # Calculate weighted average term
    total_recurring = 0
    weighted_months = 0

    services.each do |service|
      recurring_revenue = (service.tcv || 0) - (service.nrcs || 0)
      if recurring_revenue.positive?
        total_recurring += recurring_revenue
        weighted_months += service.term_months_as_delivered * recurring_revenue
      end
    end

    return 0 if total_recurring.zero? || weighted_months.zero?

    average_term_months = weighted_months.to_f / total_recurring
    total_recurring / average_term_months
  end

  private

  # Normalizes order number to ensure consistency
  # Strips whitespace and converts to uppercase
  def normalize_order_number
    self.order_number = order_number.to_s.strip.upcase if order_number.present?
  end

  # Updates order totals by aggregating values from associated services
  # Called automatically before save to ensure order totals stay in sync
  def calculate_totals
    self.tcv = calculate_tcv
    self.baseline_mrr = calculate_mrr
    self.gaap_mrr = calculate_gaap_mrr
  end

  # Validates that de-book orders must reference an original order
  def de_book_requires_original_order
    return unless is_de_book?

    return unless original_order_id.blank?
      errors.add(:original_order_id, "is required for de-book orders")
  end

  # Validates that renewal orders must reference an original order
  def renewal_requires_original_order
    return unless is_renewal?

    return unless original_order_id.blank?
      errors.add(:original_order_id, "is required for renewal orders")
  end

  # Validates financial values have correct sign based on order type
  def financial_values_sign_validation
    return unless tcv.present? || baseline_mrr.present? || gaap_mrr.present?

    if is_de_book?
      # De-book orders should have negative values
      errors.add(:tcv, "must be negative for de-book orders") if tcv.present? && tcv.positive?
      errors.add(:baseline_mrr, "must be negative for de-book orders") if baseline_mrr.present? && baseline_mrr.positive?
      errors.add(:gaap_mrr, "must be negative for de-book orders") if gaap_mrr.present? && gaap_mrr.positive?
    else
      # All other orders should have non-negative values
      errors.add(:tcv, "must be greater than or equal to 0") if tcv.present? && tcv.negative?
      errors.add(:baseline_mrr, "must be greater than or equal to 0") if baseline_mrr.present? && baseline_mrr.negative?
      errors.add(:gaap_mrr, "must be greater than or equal to 0") if gaap_mrr.present? && gaap_mrr.negative?
    end
  end
end
