require 'test_helper'

class OwnerTest < ActiveSupport::TestCase
  setup do
    @host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
  end

  test "requires login" do
    owner = Owner.new(host: @host, login: nil)
    assert_not owner.valid?
  end

  test "hidden defaults to false" do
    owner = Owner.create!(host: @host, login: "testowner")
    assert_equal false, owner.hidden
  end

  test "can be set to hidden" do
    owner = Owner.create!(host: @host, login: "testowner")
    owner.update!(hidden: true)
    assert_equal true, owner.hidden
  end

  test "visible scope excludes hidden owners" do
    visible_owner = Owner.create!(host: @host, login: "visible", hidden: false)
    hidden_owner = Owner.create!(host: @host, login: "hidden", hidden: true)

    assert_includes Owner.visible, visible_owner
    assert_not_includes Owner.visible, hidden_owner
  end

  test "hidden scope only includes hidden owners" do
    visible_owner = Owner.create!(host: @host, login: "visible", hidden: false)
    hidden_owner = Owner.create!(host: @host, login: "hidden", hidden: true)

    assert_includes Owner.hidden, hidden_owner
    assert_not_includes Owner.hidden, visible_owner
  end

  test "unique login per host" do
    Owner.create!(host: @host, login: "testowner")
    duplicate = Owner.new(host: @host, login: "testowner")
    assert_not duplicate.valid?
  end
end
