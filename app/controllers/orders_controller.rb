# Manages CRUD operations for Orders
#
# Handles creation, viewing, editing, and deletion of orders
# which track sales deals and their associated services
class OrdersController < ApplicationController
  before_action :require_login
  before_action :set_order, only: %i[show edit update destroy]
  before_action :set_customers, only: %i[new create edit update]

  # Lists all orders with their associated customers
  #
  # Orders are displayed in descending order by creation date
  def index
    @orders = Order.includes(:customer).order(created_at: :desc)
  end

  # Displays a single order with its details and services
  def show
  end

  # Renders form for creating a new order
  #
  # Initializes a new Order instance and loads customers for selection
  def new
    @order = Order.new
  end

  # Creates a new order with the provided parameters
  #
  # Automatically sets the current user as the creator of the order
  # Redirects to order detail page on success, re-renders form on failure
  def create
    @order = Order.new(order_params)
    @order.created_by = current_user

    if @order.save
      redirect_to @order, notice: "Order was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Renders form for editing an existing order
  def edit
  end

  # Updates an existing order with the provided parameters
  #
  # Redirects to order detail page on success, re-renders form on failure
  def update
    if @order.update(order_params)
      redirect_to @order, notice: "Order was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Destroys an order and all associated services
  #
  # Note: Orders with dependent de-book orders cannot be deleted due to referential integrity
  def destroy
    @order.destroy!
    redirect_to orders_url, notice: "Order was successfully destroyed."
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def set_customers
    @customers = Customer.all.order(:name)
  end

  def order_params
    params.require(:order).permit(:customer_id, :order_number, :sold_date, :tcv, :order_type, :original_order_id, :sales_rep, :site, :notes)
  end
end
