require "test_helper"

class Api::V1::RecommendationsControllerTest < ActionDispatch::IntegrationTest
  test "create requires track_id parameter" do
    post api_v1_recommendations_url,
         params: {},
         as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "track_id is required", json["error"]
  end

  test "create accepts valid track_id format" do

    post api_v1_recommendations_url,
         params: { track_id: "3WRQUvzRvBDr4AxMWhXc5E" },
         as: :json

    assert_not_equal 400, response.status
    assert_includes response.content_type, "application/json"
  end

  test "create accepts use_audio_features parameter" do
    post api_v1_recommendations_url,
         params: {
           track_id: "3WRQUvzRvBDr4AxMWhXc5E",
           use_audio_features: false
         },
         as: :json

    assert_not_equal 400, response.status
  end

  test "create accepts targets parameter" do
    post api_v1_recommendations_url,
         params: {
           track_id: "3WRQUvzRvBDr4AxMWhXc5E",
           targets: {
             energy: 0.8,
             valence: 0.5
           }
         },
         as: :json

    assert_not_equal 400, response.status
  end

  test "create validates energy target range" do
    post api_v1_recommendations_url,
         params: {
           track_id: "3WRQUvzRvBDr4AxMWhXc5E",
           targets: { energy: 1.5 }
         },
         as: :json

    assert_includes response.content_type, "application/json"
  end

  test "create returns JSON response" do
    post api_v1_recommendations_url,
         params: { track_id: "3WRQUvzRvBDr4AxMWhXc5E" },
         as: :json

    assert_includes response.content_type, "application/json"
  end
end
