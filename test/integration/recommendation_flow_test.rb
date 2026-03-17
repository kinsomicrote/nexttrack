require "test_helper"

class RecommendationFlowTest < ActionDispatch::IntegrationTest
  test "homepage loads successfully" do
    get root_url
    assert_response :success
    assert_select "h1", /NEXTTRACK/i
  end

  test "health check endpoint responds" do
    get rails_health_check_url
    assert_response :success
  end

  test "API v1 recommendations endpoint exists" do
    post api_v1_recommendations_url,
         params: { track_id: "invalid" },
         as: :json

    assert_not_equal 404, response.status
  end

  test "API v1 tracks search endpoint exists" do
    get search_api_v1_tracks_url, params: { q: "test" }

    assert_not_equal 404, response.status
  end

  test "CORS headers are not set for same-origin requests" do
    get root_url
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "API returns proper content type" do
    post api_v1_recommendations_url,
         params: { track_id: "3WRQUvzRvBDr4AxMWhXc5E" },
         as: :json

    assert_includes response.content_type, "application/json"
  end
end
