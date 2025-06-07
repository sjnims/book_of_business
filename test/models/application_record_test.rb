require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "ApplicationRecord is an abstract class" do
    assert_predicate ApplicationRecord, :abstract_class?
  end
end
