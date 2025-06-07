require "test_helper"

class PackageTest < ActiveSupport::TestCase
  test "should validate ecosystem is supported by Dependabot" do
    # Valid ecosystem should pass
    package = Package.new(name: "test-package", ecosystem: "npm")
    assert package.valid?
    
    # Invalid ecosystem should fail
    package = Package.new(name: "test-package", ecosystem: "invalid-ecosystem")
    assert_not package.valid?
    assert_includes package.errors[:ecosystem], "must be a supported Dependabot ecosystem"
    
    # Unsupported but real ecosystem should fail
    package = Package.new(name: "test-package", ecosystem: "homebrew")
    assert_not package.valid?
    assert_includes package.errors[:ecosystem], "must be a supported Dependabot ecosystem"
  end
  
  test "should validate name presence" do
    package = Package.new(ecosystem: "npm")
    assert_not package.valid?
    assert_includes package.errors[:name], "can't be blank"
  end
  
  test "should validate ecosystem presence" do
    package = Package.new(name: "test-package")
    assert_not package.valid?
    assert_includes package.errors[:ecosystem], "can't be blank"
  end
  
  test "should validate name uniqueness within ecosystem" do
    Package.create!(name: "test-package", ecosystem: "npm")
    
    # Same name in same ecosystem should fail
    duplicate = Package.new(name: "test-package", ecosystem: "npm")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    
    # Same name in different ecosystem should pass
    different_ecosystem = Package.new(name: "test-package", ecosystem: "pip")
    assert different_ecosystem.valid?
  end
end
