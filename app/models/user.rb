# Represents system users with authentication and authorization
#
# Users have different roles:
# - viewer: Read-only access
# - sales_rep: Can create/edit orders
# - manager: Can manage teams and reports
# - admin: Full system access
#
# Includes password reset functionality with secure tokens
class User < ApplicationRecord
  include Auditable

  has_secure_password

  # Define roles
  enum :role, { viewer: 0, sales_rep: 1, manager: 2, admin: 3 }, default: :viewer

  # Validations
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, on: :create
  validates :password, length: { minimum: 8 }, on: :update, allow_blank: true

  # Callbacks
  before_save :downcase_email

  # Audit configuration - track important user fields
  audited :name, :email, :role

  # Password reset functionality

  # Generates a secure token for password reset and records the timestamp
  # Saves the user record without running validations
  #
  # Returns true on successful save
  def generate_password_reset_token!
    raw_token = SecureRandom.urlsafe_base64
    self.password_reset_token = raw_token
    self.password_reset_sent_at = Time.current
    save!(validate: false)
    raw_token # Return the raw token for use in URLs
  end

  # Checks if the password reset token has expired
  # Tokens expire after 2 hours for security
  #
  # Returns true if token is nil or older than 2 hours
  # Returns false if token is still valid
  def password_reset_expired?
    return true if password_reset_sent_at.nil?
    password_reset_sent_at < 2.hours.ago
  end

  # Clears password reset token and timestamp after successful reset
  # Should be called after password has been successfully changed
  def clear_password_reset!
    update!(password_reset_token: nil, password_reset_sent_at: nil)
  end

  private

  def downcase_email
    self.email = email.downcase
  end
end
