# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create default users
puts "Creating users..."

admin = User.find_or_initialize_by(email: "admin@example.com")
admin.assign_attributes(
  name: "System Administrator",
  role: "admin",
  password: "Admin123!",
  password_confirmation: "Admin123!"
)

if admin.new_record?
  admin.save!
  puts "Created admin user:"
  puts "  Email: admin@example.com"
  puts "  Password: Admin123!"
  puts "  Role: admin"
else
  puts "Admin user already exists: admin@example.com"
end

# Create additional users
users = [
  { email: "manager@example.com", name: "Jane Manager", role: "manager", password: "Manager123!" },
  { email: "sales@example.com", name: "John Sales", role: "sales_rep", password: "Sales123!" },
  { email: "viewer@example.com", name: "View Only", role: "viewer", password: "Viewer123!" },
]

users.each do |user_data|
  user = User.find_or_initialize_by(email: user_data[:email])
  user.assign_attributes(
    name: user_data[:name],
    role: user_data[:role],
    password: user_data[:password],
    password_confirmation: user_data[:password]
  )

  if user.new_record?
    user.save!
    puts "Created #{user.role} user: #{user.email}"
  end
end

puts "\nCreating customers..."

# Create sample customers
customers = [
  {
    customer_id: "CUST001",
    name: "Acme Corporation",
    email: "billing@acme.com",
    phone: "555-0100",
    billing_address: "123 Main St\nSuite 100\nNew York, NY 10001",
    technical_contact_name: "Bob Technical",
    technical_contact_email: "tech@acme.com",
    technical_contact_phone: "555-0101",
  },
  {
    customer_id: "CUST002",
    name: "Global Industries Inc",
    email: "accounts@global.com",
    phone: "555-0200",
    billing_address: "456 Corporate Blvd\nChicago, IL 60601",
    technical_contact_name: "Alice Engineer",
    technical_contact_email: "it@global.com",
    technical_contact_phone: "555-0201",
  },
  {
    customer_id: "CUST003",
    name: "Tech Startup LLC",
    email: "finance@techstartup.com",
    phone: "555-0300",
    billing_address: "789 Innovation Way\nSan Francisco, CA 94105",
    technical_contact_name: "Charlie Dev",
    technical_contact_email: "ops@techstartup.com",
    technical_contact_phone: "555-0301",
  },
]

customers.each do |customer_data|
  customer = Customer.find_or_create_by!(customer_id: customer_data[:customer_id]) do |c|
    c.assign_attributes(customer_data)
  end
  puts "Created customer: #{customer.display_name}"
end

puts "\nCreating orders and services..."

# Create orders with services
order_data = [
  # New orders
  {
    customer_id: "CUST001",
    order_number: "ORD-2024-001",
    sold_date: 3.months.ago,
    order_type: "new_order",
    sales_rep: "John Sales",
    site: "NYC-01",
    services: [
      {
        service_name: "Premium Internet 1Gbps",
        service_type: "internet",
        term_months: 36,
        billing_start_date: 2.months.ago,
        rev_rec_start_date: 2.months.ago,
        units: 1,
        unit_price: 500.00,
        nrcs: 1000.00,
        annual_escalator: 3.0,
        status: "active",
        site: "NYC-01",
      },
      {
        service_name: "Managed Firewall",
        service_type: "managed_services",
        term_months: 36,
        billing_start_date: 2.months.ago,
        rev_rec_start_date: 2.months.ago,
        units: 1,
        unit_price: 200.00,
        nrcs: 500.00,
        annual_escalator: 3.0,
        status: "active",
        site: "NYC-01",
      },
    ],
  },
  {
    customer_id: "CUST002",
    order_number: "ORD-2024-002",
    sold_date: 6.months.ago,
    order_type: "new_order",
    sales_rep: "Jane Manager",
    site: "CHI-01",
    services: [
      {
        service_name: "Business Internet 500Mbps",
        service_type: "internet",
        term_months: 24,
        billing_start_date: 5.months.ago,
        rev_rec_start_date: 5.months.ago,
        units: 2,
        unit_price: 300.00,
        nrcs: 0.00,
        annual_escalator: 2.5,
        status: "active",
        site: "CHI-01",
      },
      {
        service_name: "VoIP Phone System",
        service_type: "voice",
        term_months: 24,
        billing_start_date: 5.months.ago,
        rev_rec_start_date: 5.months.ago,
        units: 50,
        unit_price: 25.00,
        nrcs: 2000.00,
        annual_escalator: 2.5,
        status: "active",
        site: "CHI-01",
      },
    ],
  },
  # Order with expiring service
  {
    customer_id: "CUST003",
    order_number: "ORD-2023-050",
    sold_date: 23.months.ago,
    order_type: "new_order",
    sales_rep: "John Sales",
    site: "SF-01",
    services: [
      {
        service_name: "Cloud Hosting Package",
        service_type: "cloud",
        term_months: 24,
        billing_start_date: 23.months.ago,
        rev_rec_start_date: 23.months.ago,
        units: 10,
        unit_price: 100.00,
        nrcs: 0.00,
        annual_escalator: 5.0,
        status: "active",
        site: "SF-01",
      },
    ],
  },
]

order_data.each do |data|
  customer = Customer.find_by!(customer_id: data[:customer_id])

  order = Order.create!(
    customer: customer,
    order_number: data[:order_number],
    sold_date: data[:sold_date],
    order_type: data[:order_type],
    sales_rep: data[:sales_rep],
    site: data[:site],
    notes: "Seeded test order"
  )

  data[:services].each do |service_data|
    service = order.services.create!(service_data)
    puts "  Created service: #{service.display_name} for order #{order.order_number}"
  end

  puts "Created order: #{order.display_name} with #{order.services.count} services"
end

# Create a renewal order
original_order = Order.find_by(order_number: "ORD-2023-050")
if original_order && !Order.exists?(order_number: "ORD-2024-003")
  renewal_order = Order.create!(
    customer: original_order.customer,
    order_number: "ORD-2024-003",
    sold_date: 1.month.ago,
    order_type: "renewal",
    sales_rep: original_order.sales_rep,
    site: original_order.site,
    original_order: original_order,
    notes: "Renewal of #{original_order.order_number}"
  )

  # Copy and renew services
  original_order.services.each do |original_service|
    renewal_order.services.create!(
      service_name: original_service.service_name,
      service_type: original_service.service_type,
      term_months: 24,
      billing_start_date: 1.month.from_now,
      rev_rec_start_date: 1.month.from_now,
      units: original_service.units,
      unit_price: original_service.unit_price * 1.1, # 10% increase
      nrcs: 0.00,
      annual_escalator: original_service.annual_escalator,
      status: "pending_installation",
      site: original_service.site
    )
  end

  puts "Created renewal order: #{renewal_order.display_name}"
end

puts "\nSeed data created successfully!"
puts "\nSummary:"
puts "  Users: #{User.count}"
puts "  Customers: #{Customer.count}"
puts "  Orders: #{Order.count}"
puts "  Services: #{Service.count}"
puts "  Active Services: #{Service.active.count}"
puts "  Total MRR: $#{Service.active.sum(:mrr).round(2)}"
puts "  Total ARR: $#{Service.active.sum(:arr).round(2)}"
