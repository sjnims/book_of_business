# Tracks all changes made to auditable models in the system
#
# Provides comprehensive audit trail for compliance and debugging
# Stores who made changes, what changed, when, and from where
#
# Polymorphic association allows tracking any model that includes Auditable
class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :auditable, polymorphic: true

  validates :action, presence: true
  validates :auditable_type, presence: true
  validates :auditable_id, presence: true

  serialize :audited_changes, coder: JSON

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_auditable, ->(auditable) { where(auditable: auditable) }
  scope :for_action, ->(action) { where(action: action) }

  ACTIONS = %w[create update destroy].freeze

  validates :action, inclusion: { in: ACTIONS }

  # Returns the audited changes or empty hash if none
  #
  # Returns Hash of changes with from/to values
  def changes_summary
    return {} unless audited_changes.present?
    audited_changes
  end

  # Returns a human-readable identifier for the audited record
  #
  # Returns String in format "ModelName #id"
  def auditable_name
    "#{auditable_type} ##{auditable_id}"
  end
end
