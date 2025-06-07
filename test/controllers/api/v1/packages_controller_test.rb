require 'test_helper'

class Api::V1::PackagesControllerTest < ActionDispatch::IntegrationTest
  
  def setup
    @npm_package = Package.create!(name: 'lodash', ecosystem: 'npm')
    @ruby_package = Package.create!(name: 'rails', ecosystem: 'rubygems')
    @python_package = Package.create!(name: 'requests', ecosystem: 'pip')
  end

  test "should lookup package by npm purl" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:npm/lodash@4.17.21' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'lodash', json_response['name']
    assert_equal 'npm', json_response['ecosystem']
  end

  test "should lookup package by gem purl" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:gem/rails@7.0.0' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'rails', json_response['name']
    assert_equal 'rubygems', json_response['ecosystem']
  end

  test "should lookup package by pypi purl" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:pypi/requests@2.28.1' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'requests', json_response['name']
    assert_equal 'pip', json_response['ecosystem']
  end

  test "should ignore version in purl" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:npm/lodash@1.0.0' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'lodash', json_response['name']
    assert_equal 'npm', json_response['ecosystem']
  end

  test "should handle purl without version" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:npm/lodash' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'lodash', json_response['name']
    assert_equal 'npm', json_response['ecosystem']
  end

  test "should return 400 for missing purl parameter" do
    get lookup_api_v1_packages_path
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal 'PURL parameter is required', json_response['error']
  end

  test "should return 400 for invalid purl format" do
    get lookup_api_v1_packages_path, params: { purl: 'invalid-purl' }
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_includes json_response['error'], 'Invalid PURL format'
  end

  test "should return 400 for unsupported purl type" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:unsupported/package@1.0.0' }
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal 'Unsupported PURL type: unsupported', json_response['error']
  end

  test "should return 404 for non-existent package" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:npm/non-existent-package@1.0.0' }
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'Package not found', json_response['error']
  end

  test "should handle different purl type mappings" do
    # Test various PURL type to ecosystem mappings
    test_cases = [
      { purl: 'pkg:npm/lodash', ecosystem: 'npm' },
      { purl: 'pkg:gem/rails', ecosystem: 'rubygems' },
      { purl: 'pkg:pypi/requests', ecosystem: 'pip' }
    ]

    test_cases.each do |test_case|
      get lookup_api_v1_packages_path, params: { purl: test_case[:purl] }
      
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal test_case[:ecosystem], json_response['ecosystem'], 
        "Failed for PURL: #{test_case[:purl]}"
    end
  end

  test "should handle scoped npm packages" do
    scoped_package = Package.create!(name: '@angular/core', ecosystem: 'npm')
    
    get lookup_api_v1_packages_path, params: { purl: 'pkg:npm/@angular/core@12.0.0' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal '@angular/core', json_response['name']
    assert_equal 'npm', json_response['ecosystem']
  end

  test "should return json format" do
    get lookup_api_v1_packages_path, params: { purl: 'pkg:npm/lodash@4.17.21' }
    
    assert_response :success
    assert_equal 'application/json', response.content_type.split(';').first
  end

  test "should include package metadata in response" do
    @npm_package.update!(metadata: { 'description' => 'A utility library' })
    
    get lookup_api_v1_packages_path, params: { purl: 'pkg:npm/lodash@4.17.21' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'lodash', json_response['name']
    assert_equal 'npm', json_response['ecosystem']
    assert_includes json_response.keys, 'metadata'
  end

  test "should handle maven packages with namespace" do
    maven_package = Package.create!(name: 'org.springframework:spring-core', ecosystem: 'maven')
    
    get lookup_api_v1_packages_path, params: { purl: 'pkg:maven/org.springframework/spring-core@5.3.21' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'org.springframework:spring-core', json_response['name']
    assert_equal 'maven', json_response['ecosystem']
  end

  test "should handle docker packages with namespace" do
    docker_package = Package.create!(name: 'library/nginx', ecosystem: 'docker')
    
    get lookup_api_v1_packages_path, params: { purl: 'pkg:docker/nginx@1.21.0' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'library/nginx', json_response['name']
    assert_equal 'docker', json_response['ecosystem']
  end

  test "should handle docker packages with explicit namespace" do
    docker_package = Package.create!(name: 'bitnami/nginx', ecosystem: 'docker')
    
    get lookup_api_v1_packages_path, params: { purl: 'pkg:docker/bitnami/nginx@1.21.0' }
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'bitnami/nginx', json_response['name']
    assert_equal 'docker', json_response['ecosystem']
  end
end