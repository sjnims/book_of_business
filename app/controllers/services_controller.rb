# Manages CRUD operations for Services within Orders
#
# Handles creation, viewing, editing, and deletion of services
# which are nested resources under orders
class ServicesController < ApplicationController
  before_action :require_login
  before_action :set_order
  before_action :set_service, only: %i[show edit update destroy]

  # Displays a single service within an order
  def show
  end

  # Renders form for adding a new service to an order
  #
  # Initializes a new Service instance associated with the parent order
  def new
    @service = @order.services.build
  end

  # Creates a new service for the specified order
  #
  # Service inherits order context and calculates revenue fields automatically
  # Redirects to parent order on success, re-renders form on failure
  def create
    @service = @order.services.build(service_params)

    if @service.save
      redirect_to @order, notice: "Service was successfully added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Renders form for editing an existing service
  def edit
  end

  # Updates an existing service with the provided parameters
  #
  # Recalculates revenue fields based on updated values
  # Handles status transitions if action parameter is present
  # Redirects to parent order on success, re-renders form on failure
  def update
    # Handle status transitions
    if params[:service][:action].present?
      if handle_status_transition(params[:service][:action])
        redirect_to order_service_path(@order, @service), notice: "Service status updated successfully."
      else
        redirect_to order_service_path(@order, @service), alert: "Unable to update service status."
      end
    elsif @service.update(service_params)
      redirect_to @order, notice: "Service was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Destroys a service from an order
  #
  # Parent order totals are automatically recalculated after deletion
  def destroy
    @service.destroy!
    redirect_to @order, notice: "Service was successfully removed."
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  end

  def set_service
    @service = @order.services.find(params[:id])
  end

  def service_params
    params.require(:service).permit(
      :service_type, :service_name, :term_months, :status,
      :units, :unit_price, :nrcs, :annual_escalator,
      :billing_start_date, :billing_end_date,
      :rev_rec_start_date, :rev_rec_end_date,
      :site
    )
  end

  def handle_status_transition(action)
    case action
    when "activate"
      @service.activate!
    when "cancel"
      @service.cancel!
    when "renew"
      @service.renew!
    else
      false
    end
  end
end
