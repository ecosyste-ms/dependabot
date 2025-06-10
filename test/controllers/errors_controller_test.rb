require 'test_helper'

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test 'renders 404 with proper meta tags' do
    get '/404'
    assert_response :not_found
    assert_template 'errors/not_found'
    
    # Check content
    assert_select 'h2', "We can't find whatever it was you were looking for."
    assert_match "It may have been deleted, or might not even exist.", response.body
    
    # Check meta title and description are set
    assert_match "Page Not Found (404)", response.body
    assert_match "doesn&#39;t exist", response.body
  end

  test 'renders 422 with proper meta tags' do
    get '/422'
    assert_response :unprocessable_entity
    assert_template 'errors/unprocessable'
    
    # Check content
    assert_select 'h2', 'Unprocessable request'
    assert_match "Check your request parameters and try again.", response.body
    
    # Check meta title and description are set
    assert_match "Unprocessable Request (422)", response.body
    assert_match "couldn&#39;t be processed", response.body
  end

  test 'renders 500 with proper meta tags' do
    get '/500'
    assert_response :internal_server_error
    assert_template 'errors/internal'
    
    # Check content
    assert_select 'h2', "Oops, We've had a problem at our end."
    assert_match "Hopefully this a temporary setback.", response.body
    
    # Check meta title and description are set
    assert_match "Server Error (500)", response.body
    assert_match "We&#39;re experiencing technical difficulties", response.body
  end
end