require "test_helper"

class ServiceStatusUpdateJobTest < ActiveJob::TestCase
  setup do
    @customer = customers(:acme)
    @order = Order.create!(
      customer: @customer,
      order_number: "TEST-JOB-001",
      sold_date: Date.current,
      order_type: "new_order",
      tcv: 50_000
    )
  end

  test "updates active services past billing end date to extended" do
    # Create an active service that ended yesterday
    start_date = 12.months.ago
    end_date = start_date + 12.months - 1.day

    expired_service = @order.services.create!(
      service_name: "Expired Service",
      service_type: "internet",
      status: "active",
      term_months: 12,
      billing_start_date: start_date,
      billing_end_date: end_date,
      rev_rec_start_date: start_date,
      rev_rec_end_date: end_date,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    assert_equal "active", expired_service.status

    # Run the job
    ServiceStatusUpdateJob.perform_now

    # Check the results
    expired_service.reload

    assert_equal "extended", expired_service.status
  end

  test "does not update active services still within term" do
    # Create an active service still within term
    active_service = @order.services.create!(
      service_name: "Active Service",
      service_type: "internet",
      status: "active",
      term_months: 12,
      billing_start_date: 6.months.ago,
      billing_end_date: 6.months.from_now,
      rev_rec_start_date: 6.months.ago,
      rev_rec_end_date: 6.months.from_now,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    assert_equal "active", active_service.status

    # Run the job
    ServiceStatusUpdateJob.perform_now

    # Should still be active
    active_service.reload

    assert_equal "active", active_service.status
  end

  test "does not update services already in extended status" do
    # Create a service already marked as extended
    start_date = 12.months.ago
    end_date = start_date + 12.months - 1.day

    extended_service = @order.services.create!(
      service_name: "Already Extended",
      service_type: "internet",
      status: "extended",
      term_months: 12,
      billing_start_date: start_date,
      billing_end_date: end_date,
      rev_rec_start_date: start_date,
      rev_rec_end_date: end_date,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    assert_equal "extended", extended_service.status

    # Run the job
    ServiceStatusUpdateJob.perform_now

    # Should still be extended
    extended_service.reload

    assert_equal "extended", extended_service.status
  end

  test "does not update canceled or renewed services" do
    # Create canceled and renewed services past their end dates
    start_date = 12.months.ago
    end_date = start_date + 12.months - 1.day

    canceled_service = @order.services.create!(
      service_name: "Canceled Service",
      service_type: "internet",
      status: "canceled",
      term_months: 12,
      billing_start_date: start_date,
      billing_end_date: end_date,
      rev_rec_start_date: start_date,
      rev_rec_end_date: end_date,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    renewed_service = @order.services.create!(
      service_name: "Renewed Service",
      service_type: "internet",
      status: "renewed",
      term_months: 12,
      billing_start_date: start_date,
      billing_end_date: end_date,
      rev_rec_start_date: start_date,
      rev_rec_end_date: end_date,
      units: 1,
      unit_price: 1000,
      nrcs: 0,
      annual_escalator: 3
    )

    # Run the job
    ServiceStatusUpdateJob.perform_now

    # Status should remain unchanged
    canceled_service.reload
    renewed_service.reload

    assert_equal "canceled", canceled_service.status
    assert_equal "renewed", renewed_service.status
  end

  test "job can be performed successfully" do
    # Just test that the job runs without errors
    assert_nothing_raised do
      ServiceStatusUpdateJob.perform_now
    end
  end
end
