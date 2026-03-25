require 'test_helper'

class RepositoryOwnerTest < ActiveSupport::TestCase
  setup do
    @host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    @repository = Repository.create!(host: @host, full_name: 'test/repo', owner: 'test')
  end

  test "owner_hidden? returns false when no owner record exists" do
    assert_equal false, @repository.owner_hidden?
  end

  test "owner_hidden? returns false for visible owner" do
    Owner.create!(host: @host, login: 'test', hidden: false)
    assert_equal false, @repository.owner_hidden?
  end

  test "owner_hidden? returns true for hidden owner" do
    Owner.create!(host: @host, login: 'test', hidden: true)
    assert_equal true, @repository.owner_hidden?
  end

  test "owner_hidden? returns false for nil hidden owner" do
    Owner.create!(host: @host, login: 'test', hidden: nil)
    assert_equal false, @repository.owner_hidden?
  end
end
