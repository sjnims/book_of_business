# Concern for adding audit trail functionality to ActiveRecord models
#
# Include this module in any model that needs change tracking
# Automatically logs create, update, and destroy actions
#
# Usage:
#   class User < ApplicationRecord
#     include Auditable
#     audited :name, :email  # Track only specific fields
#   end
module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, as: :auditable, dependent: :destroy

    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy

    class_attribute :audited_attributes
    class_attribute :excluded_attributes

    self.excluded_attributes = %w[id created_at updated_at]
  end

  class_methods do
    # Specifies which attributes to track for auditing
    # If not called, all attributes except excluded ones are tracked
    #
    # Example: audited :name, :email, :role
    def audited(*attributes)
      self.audited_attributes = attributes.map(&:to_s)
    end

    # Adds attributes to the exclusion list for auditing
    # By default excludes: id, created_at, updated_at
    #
    # Example: audit_exclude :password_digest, :token
    def audit_exclude(*attributes)
      self.excluded_attributes += attributes.map(&:to_s)
    end
  end

  private

  def log_create
    create_audit_log("create", auditable_attributes_for_create)
  end

  def log_update
    return unless saved_changes?
    changes_to_log = auditable_changes
    return if changes_to_log.empty?

    create_audit_log("update", changes_to_log)
  end

  def log_destroy
    create_audit_log("destroy", auditable_attributes_for_destroy)
  end

  def create_audit_log(action, changes)
    return unless Current.user

    AuditLog.create!(
      auditable: self,
      user: Current.user,
      action: action,
      audited_changes: changes,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      metadata: audit_metadata
    )
  end

  def auditable_changes
    changes = saved_changes.except(*excluded_attributes)

    changes = changes.slice(*audited_attributes) if audited_attributes.present?

    changes.transform_values do |values|
      { "from" => values[0], "to" => values[1] }
    end
  end

  def auditable_attributes_for_create
    attrs = attributes.except(*excluded_attributes)

    attrs = attrs.slice(*audited_attributes) if audited_attributes.present?

    attrs.transform_values { |value| { "from" => nil, "to" => value } }
  end

  def auditable_attributes_for_destroy
    attrs = attributes.except(*excluded_attributes)

    attrs = attrs.slice(*audited_attributes) if audited_attributes.present?

    attrs.transform_values { |value| { "from" => value, "to" => nil } }
  end

  def audit_metadata
    {}
  end
end
