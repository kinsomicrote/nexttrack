require "test_helper"

class Api::V1::TracksControllerTest < ActionDispatch::IntegrationTest
  test "search returns empty results for missing query parameter" do
    get search_api_v1_tracks_url

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal [], json["results"]
  end

  test "search returns empty results for query under 2 characters" do
    get search_api_v1_tracks_url, params: { q: "a" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal [], json["results"]
  end

  test "search returns JSON response" do
    get search_api_v1_tracks_url, params: { q: "test query" }

    assert_includes response.content_type, "application/json"
  end
end
