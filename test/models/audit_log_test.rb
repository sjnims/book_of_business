require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @customer = customers(:acme)
    Current.user = @user
    Current.ip_address = "127.0.0.1"
    Current.user_agent = "Test Browser"
  end

  teardown do
    Current.reset
  end

  test "should create audit log with valid attributes" do
    audit_log = AuditLog.new(
      auditable: @customer,
      user: @user,
      action: "create",
      audited_changes: { "name" => { "from" => nil, "to" => "Test Customer" } },
      ip_address: "127.0.0.1",
      user_agent: "Test Browser"
    )

    assert_predicate audit_log, :valid?
    assert audit_log.save
  end

  test "should require user" do
    audit_log = AuditLog.new(
      auditable: @customer,
      action: "update"
    )

    assert_not audit_log.valid?
    assert_includes audit_log.errors[:user], "must exist"
  end

  test "should require action" do
    audit_log = AuditLog.new(
      auditable: @customer,
      user: @user
    )

    assert_not audit_log.valid?
    assert_includes audit_log.errors[:action], "can't be blank"
  end

  test "should validate action inclusion" do
    audit_log = AuditLog.new(
      auditable: @customer,
      user: @user,
      action: "invalid_action"
    )

    assert_not audit_log.valid?
    assert_includes audit_log.errors[:action], "is not included in the list"
  end

  test "should accept valid actions" do
    %w[create update destroy].each do |action|
      audit_log = AuditLog.new(
        auditable: @customer,
        user: @user,
        action: action
      )

      assert_predicate audit_log, :valid?
    end
  end

  test "should serialize audited_changes as JSON" do
    changes = { "name" => { "from" => "Old Name", "to" => "New Name" } }
    audit_log = AuditLog.create!(
      auditable: @customer,
      user: @user,
      action: "update",
      audited_changes: changes
    )

    audit_log.reload

    assert_equal changes, audit_log.audited_changes
  end

  test "recent scope should order by created_at desc" do
    AuditLog.destroy_all

    old_log = AuditLog.create!(
      auditable: @customer,
      user: @user,
      action: "create",
      created_at: 2.days.ago
    )

    new_log = AuditLog.create!(
      auditable: @customer,
      user: @user,
      action: "update",
      created_at: 1.hour.ago
    )

    assert_equal [ new_log, old_log ], AuditLog.recent.to_a
  end

  test "for_user scope should filter by user" do
    other_user = users(:sales_rep)

    user_log = AuditLog.create!(
      auditable: @customer,
      user: @user,
      action: "update"
    )

    other_log = AuditLog.create!(
      auditable: @customer,
      user: other_user,
      action: "update"
    )

    assert_includes AuditLog.for_user(@user), user_log
    assert_not_includes AuditLog.for_user(@user), other_log
  end

  test "for_auditable scope should filter by auditable" do
    other_customer = customers(:globex)

    customer_log = AuditLog.create!(
      auditable: @customer,
      user: @user,
      action: "update"
    )

    other_log = AuditLog.create!(
      auditable: other_customer,
      user: @user,
      action: "update"
    )

    assert_includes AuditLog.for_auditable(@customer), customer_log
    assert_not_includes AuditLog.for_auditable(@customer), other_log
  end

  test "for_action scope should filter by action" do
    create_log = AuditLog.create!(
      auditable: @customer,
      user: @user,
      action: "create"
    )

    update_log = AuditLog.create!(
      auditable: @customer,
      user: @user,
      action: "update"
    )

    assert_includes AuditLog.for_action("create"), create_log
    assert_not_includes AuditLog.for_action("create"), update_log
  end

  test "changes_summary should return audited_changes" do
    changes = { "name" => { "from" => "Old", "to" => "New" } }
    audit_log = AuditLog.new(
      auditable: @customer,
      user: @user,
      action: "update",
      audited_changes: changes
    )

    assert_equal changes, audit_log.changes_summary
  end

  test "changes_summary should return empty hash when no changes" do
    audit_log = AuditLog.new(
      auditable: @customer,
      user: @user,
      action: "update"
    )

    assert_empty(audit_log.changes_summary)
  end

  test "auditable_name should return formatted name" do
    audit_log = AuditLog.new(
      auditable: @customer,
      user: @user,
      action: "update"
    )

    assert_equal "Customer ##{@customer.id}", audit_log.auditable_name
  end
end
