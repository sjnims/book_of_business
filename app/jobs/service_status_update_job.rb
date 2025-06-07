# Job to automatically update service statuses based on their contract dates
#
# This job handles automatic status transitions such as:
# - Marking active services as "extended" when they go past their billing end date
#
# This should be run daily via a recurring job
class ServiceStatusUpdateJob < ApplicationJob
  queue_as :default

  # Performs the status update for all services that need it
  def perform
    update_extended_services
  end

  private

  # Updates active services to extended status if they're past their billing end date
  #
  # Returns the number of services updated
  def update_extended_services
    services_to_extend = Service.needs_extension
    updated_count = 0

    services_to_extend.find_each do |service|
      if service.update_extended_status!
        updated_count += 1
        Rails.logger.info("Updated service #{service.id} to extended status")
      end
    end

    Rails.logger.info("ServiceStatusUpdateJob: Updated #{updated_count} services to extended status")
    updated_count
  end
end
