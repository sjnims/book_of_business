# Stores request-specific attributes for use throughout the application
#
# Uses Rails CurrentAttributes to provide thread-safe storage
# of current user and request information for audit logging
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :ip_address, :user_agent
end
