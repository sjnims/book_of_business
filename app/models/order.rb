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
  # Associations
  belongs_to :customer
  belongs_to :original_order, class_name: "Order", optional: true
  has_many :renewal_orders, class_name: "Order", foreign_key: "original_order_id",
           dependent: :restrict_with_error, inverse_of: :original_order
  has_many :services, dependent: :destroy

  # Order types
  ORDER_TYPES = %w[new_order renewal upgrade downgrade cancellation].freeze

  # Validations
  validates :order_number, presence: true, uniqueness: { case_sensitive: false }
  validates :sold_date, presence: true
  validates :order_type, inclusion: { in: ORDER_TYPES }
  validates :tcv, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :baseline_mrr, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gaap_mrr, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

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
        weighted_months += service.term_months * recurring_revenue
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
end
