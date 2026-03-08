require "test_helper"

class HostTest < ActiveSupport::TestCase
  test 'find_by_name finds host by exact name' do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    assert_equal host, Host.find_by_name('GitHub')
  end

  test 'find_by_name finds host case-insensitively' do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    assert_equal host, Host.find_by_name('github')
    assert_equal host, Host.find_by_name('GITHUB')
  end

  test 'find_by_name falls back to domain lookup' do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    assert_equal host, Host.find_by_name('github.com')
  end

  test 'find_by_name returns nil for blank name' do
    assert_nil Host.find_by_name('')
    assert_nil Host.find_by_name(nil)
  end

  test 'find_by_name returns nil for non-existent name' do
    assert_nil Host.find_by_name('nonexistent')
  end

  test 'find_by_name! finds host by name' do
    host = Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    assert_equal host, Host.find_by_name!('GitHub')
  end

  test 'find_by_name! raises RecordNotFound for non-existent name' do
    assert_raises(ActiveRecord::RecordNotFound) { Host.find_by_name!('nonexistent') }
  end

  test 'find_by_name! raises RecordNotFound for blank name' do
    assert_raises(ActiveRecord::RecordNotFound) { Host.find_by_name!(nil) }
  end

  test 'validates uniqueness case-insensitively' do
    Host.create!(name: 'GitHub', url: 'https://github.com', kind: 'github')
    host = Host.new(name: 'github', url: 'https://github2.com', kind: 'github')
    assert_not host.valid?
    assert_includes host.errors[:name], 'has already been taken'
  end
end
