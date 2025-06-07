# Configure Solid Queue for recurring jobs
#
# This initializer sets up Solid Queue to handle recurring jobs
# defined in config/recurring.yml

Rails.application.configure do
  # Configure Solid Queue as the Active Job adapter
  config.active_job.queue_adapter = :solid_queue

  # Load recurring jobs configuration if in production or development
  config.solid_queue.recurring_tasks = Rails.application.config_for(:recurring) if Rails.env.production? || Rails.env.development?
end
