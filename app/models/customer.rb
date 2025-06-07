# Represents customer accounts in the system
#
# Customers are the primary entity that:
# - Own orders and services
# - Have billing and technical contact information
# - Track total revenue metrics across all services
#
# Cannot be deleted if they have associated orders
class Customer < ApplicationRecord
  include Auditable

  # Associations
  has_many :orders, dependent: :restrict_with_error
  has_many :services, through: :orders

  # Validations
  validates :customer_id, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :technical_contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Scopes
  scope :active, -> { joins(:services).where(services: { status: "active" }).distinct }
  scope :by_name, -> { order(:name) }
  scope :search, ->(query) { where("name ILIKE ? OR customer_id ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%", "%#{query}%") }

  # Callbacks
  before_validation :normalize_customer_id

  # Audit configuration - track all customer data changes
  audit_exclude :created_at, :updated_at

  # Instance methods

  # Returns a formatted display name combining customer ID and name
  #
  # Returns String in format "CUSTOMER_ID - Customer Name"
  def display_name
    "#{customer_id} - #{name}"
  end

  # Returns all services with active status for this customer
  #
  # Returns ActiveRecord::Relation of active services
  def active_services
    services.where(status: "active")
  end

  # Calculates total Monthly Recurring Revenue across all active services
  #
  # Returns the sum of MRR from all services with status 'active'
  def total_mrr
    active_services.sum(:mrr)
  end

  # Calculates total Annual Recurring Revenue across all active services
  #
  # Returns the sum of ARR from all services with status 'active'
  def total_arr
    active_services.sum(:arr)
  end

  # Checks if the customer has any active services
  #
  # Returns true if at least one active service exists, false otherwise
  def has_active_services?
    active_services.exists?
  end

  private

  # Normalizes customer_id to ensure consistency
  # Strips whitespace and converts to uppercase
  def normalize_customer_id
    self.customer_id = customer_id.to_s.strip.upcase if customer_id.present?
  end
end
