require "test_helper"

class AuditableTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @customer = customers(:acme)
    Current.user = @user
    Current.ip_address = "192.168.1.1"
    Current.user_agent = "Mozilla/5.0"
  end

  teardown do
    Current.reset
  end

  test "should create audit log on create" do
    assert_difference "AuditLog.count", 1 do
      Customer.create!(
        customer_id: "TEST123",
        name: "Test Customer",
        email: "test@example.com"
      )
    end
  end

  test "audit log on create should have correct action and user" do
    Customer.create!(customer_id: "TEST123", name: "Test Customer")
    audit_log = AuditLog.last

    assert_equal "create", audit_log.action
    assert_equal @user, audit_log.user
  end

  test "audit log on create should track request details" do
    Customer.create!(customer_id: "TEST123", name: "Test Customer")
    audit_log = AuditLog.last

    assert_equal "192.168.1.1", audit_log.ip_address
    assert_equal "Mozilla/5.0", audit_log.user_agent
    assert_equal "Customer", audit_log.auditable_type
  end

  test "should create audit log on update" do
    assert_difference "AuditLog.count", 1 do
      @customer.update!(name: "Updated Name")
    end
  end

  test "audit log on update should track changes correctly" do
    @customer.update!(name: "Updated Name")
    audit_log = AuditLog.last

    assert_equal "update", audit_log.action
    assert_equal @customer, audit_log.auditable
    assert_equal({ "from" => "ACME Corporation", "to" => "Updated Name" },
                 audit_log.audited_changes["name"])
  end

  test "should create audit log on destroy" do
    assert_difference "AuditLog.count", 1 do
      # Create a customer without orders so it can be destroyed
      customer = Customer.create!(
        customer_id: "TEMP123",
        name: "Temporary Customer"
      )
      customer.destroy
    end

    audit_log = AuditLog.last

    assert_equal "destroy", audit_log.action
  end

  test "should not create audit log without current user" do
    Current.user = nil

    assert_no_difference "AuditLog.count" do
      @customer.update!(name: "No Audit")
    end
  end

  test "should exclude specified attributes from audit" do
    # User model excludes password-related fields
    user = User.create!(
      name: "Test User",
      email: "newuser@example.com",
      password: "password123",
      role: "viewer"
    )

    audit_log = AuditLog.last

    assert_nil audit_log.audited_changes["password_digest"]
    assert_nil audit_log.audited_changes["created_at"]
    assert_nil audit_log.audited_changes["updated_at"]
  end

  test "should track only audited attributes when specified" do
    # Create a test model that uses audited
    user = users(:sales_rep)
    user.update!(name: "New Name", email: "newemail@example.com")

    audit_log = AuditLog.last

    assert audit_log.audited_changes.key?("name")
    assert audit_log.audited_changes.key?("email")
  end

  test "should track changes to order model" do
    order = orders(:order_one)

    assert_difference "AuditLog.count", 1 do
      order.update!(notes: "Updated notes")
    end
  end

  test "audit log for order should have correct details" do
    order = orders(:order_one)
    order.update!(notes: "Updated notes")
    audit_log = AuditLog.last

    assert_equal "Order", audit_log.auditable_type
    assert_equal order.id, audit_log.auditable_id
    assert_equal({ "from" => "First order", "to" => "Updated notes" },
                 audit_log.audited_changes["notes"])
  end

  test "should track changes to service model" do
    service = services(:internet_service)

    assert_difference "AuditLog.count", 1 do
      service.update!(unit_price: 200.0)
    end
  end

  test "audit log for service should have correct details" do
    service = services(:internet_service)
    old_price = service.unit_price
    service.update!(unit_price: 200.0)
    audit_log = AuditLog.last

    assert_equal "Service", audit_log.auditable_type
    assert_equal service.id, audit_log.auditable_id
    assert_equal({ "from" => old_price.to_s, "to" => "200.0" },
                 audit_log.audited_changes["unit_price"])
  end

  test "should not create audit log for unchanged attributes" do
    assert_no_difference "AuditLog.count" do
      @customer.update!(name: @customer.name)
    end
  end

  test "should handle multiple changes in single update" do
    assert_difference "AuditLog.count", 1 do
      @customer.update!(
        name: "New Name",
        email: "newemail@example.com",
        phone: "555-1234"
      )
    end
  end

  test "audit log should track all changed fields" do
    @customer.update!(
      name: "New Name",
      email: "newemail@example.com",
      phone: "555-1234"
    )
    audit_log = AuditLog.last

    # Only changed fields should be tracked
    assert_equal 2, audit_log.audited_changes.keys.count
    assert audit_log.audited_changes.key?("name")
    assert audit_log.audited_changes.key?("email")
  end

  test "should track polymorphic associations correctly" do
    # Test with different model types
    customer_log = nil
    order_log = nil

    assert_difference "AuditLog.count", 2 do
      @customer.update!(name: "Customer Update")
      customer_log = AuditLog.last

      orders(:order_one).update!(notes: "Order Update")
      order_log = AuditLog.last
    end

    assert_equal "Customer", customer_log.auditable_type
    assert_equal "Order", order_log.auditable_type
  end

  test "audit logs should be destroyed when auditable is destroyed" do
    # Create a customer with audit logs
    customer = Customer.create!(
      customer_id: "AUDIT123",
      name: "Audit Test Customer"
    )
    customer.update!(name: "Updated Name")

    assert_equal 2, customer.audit_logs.count # create + update

    assert_difference "AuditLog.count", -1 do # -2 from existing + 1 for destroy
      customer.destroy
    end
  end
end
