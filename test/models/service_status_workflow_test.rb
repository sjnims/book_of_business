require "test_helper"

class ServiceStatusWorkflowTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:acme)
    @order = Order.create!(
      customer: @customer,
      order_number: "TEST-001",
      sold_date: Date.current,
      order_type: "new_order",
      tcv: 50_000,
      created_by: users(:admin)
    )
    @service = @order.services.create!(
      service_name: "Test Service",
      service_type: "internet",
      status: "pending_installation",
      term_months_as_sold: 36,
      billing_start_date_as_sold: Date.current,
      rev_rec_start_date_as_sold: Date.current,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )
  end

  test "should activate a pending installation service" do
    assert_equal "pending_installation", @service.status
    assert_predicate @service, :can_activate?
    assert @service.activate!
  end

  test "activated service has active status and cannot be activated again" do
    @service.activate!

    assert_equal "active", @service.status
    assert_not @service.can_activate?
  end

  test "should not activate a service that is already active" do
    @service.update!(status: "active")

    assert_not @service.can_activate?
    assert_not @service.activate!
    assert_equal "active", @service.status
  end

  test "service should automatically extend when past billing end date" do
    # Create a service that's past its billing end date
    start_date = 12.months.ago
    end_date = start_date + 12.months - 1.day

    expired_service = @order.services.create!(
      service_name: "Expired Service",
      service_type: "internet",
      status: "active",
      term_months_as_sold: 12,
      billing_start_date_as_sold: start_date,
      billing_end_date_as_sold: end_date,
      rev_rec_start_date_as_sold: start_date,
      rev_rec_end_date_as_sold: end_date,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    assert_predicate expired_service, :should_be_extended?
    assert expired_service.update_extended_status!
    assert_equal "extended", expired_service.status
  end

  test "active service within term should not be extended" do
    @service.update!(status: "active")

    assert_not @service.should_be_extended?
    assert_not @service.update_extended_status!

    assert_equal "active", @service.status
  end

  test "non-active service should not be extended" do
    assert_equal "pending_installation", @service.status
    assert_not @service.should_be_extended?
    assert_not @service.update_extended_status!
  end

  test "pending service remains pending after extension attempt" do
    assert_equal "pending_installation", @service.status
    @service.update_extended_status!

    assert_equal "pending_installation", @service.status
  end

  test "should cancel a pending installation service" do
    assert_equal "pending_installation", @service.status
    assert_predicate @service, :can_cancel?
    assert @service.cancel!
  end

  test "canceled service has canceled status and cannot be canceled again" do
    @service.cancel!

    assert_equal "canceled", @service.status
    assert_not @service.can_cancel?
  end

  test "should cancel an active service" do
    @service.update!(status: "active")

    assert_predicate @service, :can_cancel?

    assert @service.cancel!
    assert_equal "canceled", @service.status
  end

  test "should not cancel an already canceled service" do
    @service.update!(status: "canceled")

    assert_not @service.can_cancel?
    assert_not @service.cancel!
    assert_equal "canceled", @service.status
  end

  test "should not cancel an extended service" do
    @service.update!(status: "extended")

    assert_not @service.can_cancel?
    assert_not @service.cancel!
  end

  test "extended service status unchanged after cancel attempt" do
    @service.update!(status: "extended")
    @service.cancel!

    assert_equal "extended", @service.status
  end

  test "should not cancel a renewed service" do
    @service.update!(status: "renewed")

    assert_not @service.can_cancel?
    assert_not @service.cancel!
  end

  test "renewed service status unchanged after cancel attempt" do
    @service.update!(status: "renewed")
    @service.cancel!

    assert_equal "renewed", @service.status
  end

  test "should renew an active service" do
    @service.update!(status: "active")

    assert_predicate @service, :can_renew?
    assert @service.renew!
  end

  test "renewed service has renewed status and cannot be renewed again" do
    @service.update!(status: "active")
    @service.renew!

    assert_equal "renewed", @service.status
    assert_not @service.can_renew?
  end

  test "should renew an extended service" do
    @service.update!(status: "extended")

    assert_predicate @service, :can_renew?

    assert @service.renew!
    assert_equal "renewed", @service.status
  end

  test "should not renew a pending installation service" do
    assert_equal "pending_installation", @service.status
    assert_not @service.can_renew?
    assert_not @service.renew!
  end

  test "pending service status unchanged after renew attempt" do
    assert_not @service.renew!
    assert_equal "pending_installation", @service.status
  end

  test "should not renew a canceled service" do
    @service.update!(status: "canceled")

    assert_not @service.can_renew?
    assert_not @service.renew!
    assert_equal "canceled", @service.status
  end

  test "should track status changes in audit log" do
    Current.user = users(:admin)

    assert_difference "AuditLog.count", 1 do
      @service.activate!
    end
  ensure
    Current.user = nil
  end

  test "audit log contains correct status change details" do
    Current.user = users(:admin)
    @service.activate!

    audit = AuditLog.last

    assert_equal "Service", audit.auditable_type
    assert_equal @service.id, audit.auditable_id
    assert_equal "update", audit.action
  ensure
    Current.user = nil
  end

  test "audit log tracks status transition values" do
    Current.user = users(:admin)
    @service.activate!

    audit = AuditLog.last

    assert audit.audited_changes.key?("status")
    assert_equal "pending_installation", audit.audited_changes["status"]["from"]
    assert_equal "active", audit.audited_changes["status"]["to"]
  ensure
    Current.user = nil
  end

  test "service transitions from pending to active" do
    assert_equal "pending_installation", @service.status
    assert @service.activate!
    assert_equal "active", @service.status
  end

  test "expired service automatically transitions from active to extended" do
    start_date = 12.months.ago
    end_date = start_date + 12.months - 1.day

    expired_service = @order.services.create!(
      service_name: "Expired Service",
      service_type: "internet",
      status: "active",
      term_months_as_sold: 12,
      billing_start_date_as_sold: start_date,
      billing_end_date_as_sold: end_date,
      rev_rec_start_date_as_sold: start_date,
      rev_rec_end_date_as_sold: end_date,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    # This would typically be done by a background job
    assert expired_service.update_extended_status!
    assert_equal "extended", expired_service.status
  end

  test "extended service transitions to renewed" do
    @service.update!(status: "extended")

    assert @service.renew!
    assert_equal "renewed", @service.status
  end

  test "pending service can be canceled" do
    assert_equal "pending_installation", @service.status
    assert @service.cancel!
    assert_equal "canceled", @service.status
  end

  test "canceled service cannot transition to other states" do
    @service.update!(status: "canceled")

    assert_not @service.activate!
    assert_not @service.update_extended_status!
    assert_not @service.renew!
  end

  test "alternative workflow: active to canceled" do
    @service.activate!

    assert_equal "active", @service.status

    assert @service.cancel!
    assert_equal "canceled", @service.status
  end

  test "alternative workflow: active to renewed directly" do
    @service.activate!

    assert_equal "active", @service.status

    assert @service.renew!
    assert_equal "renewed", @service.status
  end
end
