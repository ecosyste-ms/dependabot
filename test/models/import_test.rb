require "test_helper"

class ImportTest < ActiveSupport::TestCase
  test "sanitize_string removes null bytes" do
    # Test the private method through a helper
    assert_equal "helloworld", Import.send(:sanitize_string, "hello\0world")
    assert_equal "teststring", Import.send(:sanitize_string, "test\0\0string")
    assert_nil Import.send(:sanitize_string, nil)
    assert_equal "", Import.send(:sanitize_string, "")
    assert_equal "normal", Import.send(:sanitize_string, "normal")
  end
end
