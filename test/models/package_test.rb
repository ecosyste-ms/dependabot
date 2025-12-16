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

  test "ECOSYSTEM_TO_PURL_TYPE maps ecosystems with official PURL types" do
    # Only bazel and julia have official PURL types per purl-spec
    assert_equal 'bazel', Package::ECOSYSTEM_TO_PURL_TYPE['bazel']
    assert_equal 'julia', Package::ECOSYSTEM_TO_PURL_TYPE['julia']
  end

  test "purl_type returns official type for ecosystems with PURL spec support" do
    bazel_pkg = Package.new(name: "rules_go", ecosystem: "bazel")
    assert_equal 'bazel', bazel_pkg.purl_type

    julia_pkg = Package.new(name: "DataFrames", ecosystem: "julia")
    assert_equal 'julia', julia_pkg.purl_type
  end

  test "purl_type falls back to ecosystem name when no official PURL type exists" do
    # These ecosystems have no official PURL type, so they fall back to ecosystem name
    vcpkg_pkg = Package.new(name: "boost", ecosystem: "vcpkg")
    assert_equal 'vcpkg', vcpkg_pkg.purl_type

    devcontainers_pkg = Package.new(name: "node", ecosystem: "devcontainers")
    assert_equal 'devcontainers', devcontainers_pkg.purl_type

    rust_toolchain_pkg = Package.new(name: "stable", ecosystem: "rust-toolchain")
    assert_equal 'rust-toolchain', rust_toolchain_pkg.purl_type
  end

  test "should accept new Dependabot ecosystems" do
    %w[bazel devcontainers julia vcpkg rust-toolchain].each do |ecosystem|
      package = Package.new(name: "test-#{ecosystem}-package", ecosystem: ecosystem)
      assert package.valid?, "Expected #{ecosystem} to be valid but got: #{package.errors.full_messages}"
    end
  end
end
