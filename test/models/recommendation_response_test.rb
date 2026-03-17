require "test_helper"
require "ostruct"

class RecommendationResponseTest < ActiveSupport::TestCase

  test "initializes with all required parameters" do
    response = build_response

    assert response.any?
    assert_equal 2, response.count
  end

  test "handles empty recommendations" do
    response = RecommendationResponse.new(
      seed_track: build_mock_track("Seed Song", "Seed Artist"),
      seed_features: build_features,
      recommendations: [],
      audio_features_enabled: true
    )

    refute response.any?
    assert_equal 0, response.count
  end

  test "handles nil recommendations" do
    response = RecommendationResponse.new(
      seed_track: build_mock_track("Seed Song", "Seed Artist"),
      seed_features: build_features,
      recommendations: nil,
      audio_features_enabled: true
    )

    refute response.any?
    assert_equal 0, response.count
  end

  test "to_h returns hash with required top-level keys" do
    response = build_response
    result = response.to_h

    assert result.key?(:seed_track)
    assert result.key?(:recommendations)
    assert result.key?(:metadata)
  end

  test "to_h seed_track contains expected fields" do
    response = build_response
    seed = response.to_h[:seed_track]

    assert_equal "Sunset Lover", seed[:name]
    assert_equal "Petit Biscuit", seed[:artist]
    assert_equal "seed123", seed[:spotify_id]
    assert seed.key?(:features)
  end

  test "to_h seed_track features contains audio data" do
    response = build_response
    features = response.to_h[:seed_track][:features]

    assert_equal 120.0, features[:tempo]
    assert_equal "C Major", features[:key]
    assert_equal 0.8, features[:energy]
    assert_equal 0.6, features[:valence]
  end

  test "to_h recommendations is array of formatted tracks" do
    response = build_response
    recommendations = response.to_h[:recommendations]

    assert_instance_of Array, recommendations
    assert_equal 2, recommendations.length
  end

  test "to_h recommendation contains expected fields" do
    response = build_response
    rec = response.to_h[:recommendations].first

    assert_equal 1, rec[:rank]
    assert rec.key?(:track)
    assert rec.key?(:confidence)
    assert rec.key?(:reasons)
    assert rec.key?(:scores)
  end

  test "to_h recommendation track contains expected fields" do
    response = build_response
    track = response.to_h[:recommendations].first[:track]

    assert_equal "Adventure", track[:name]
    assert_equal "Madeon", track[:artist]
    assert_equal "track456", track[:spotify_id]
    assert_equal "https://open.spotify.com/track/track456", track[:spotify_url]
  end

  test "to_h metadata contains expected fields" do
    response = build_response
    metadata = response.to_h[:metadata]

    assert_equal true, metadata[:audio_features_enabled]
    assert_equal 2, metadata[:candidates_found]
    assert metadata[:processing_note].include?("cosine similarity")
  end

  test "confidence is formatted as percentage" do
    response = build_response
    rec = response.to_h[:recommendations].first

    assert_equal 85.0, rec[:confidence]
  end

  test "confidence handles nil gracefully" do
    recommendations = [build_recommendation(confidence: nil)]
    response = RecommendationResponse.new(
      seed_track: build_mock_track("Seed", "Artist"),
      seed_features: build_features,
      recommendations: recommendations,
      audio_features_enabled: true
    )

    rec = response.to_h[:recommendations].first
    assert_equal 0.0, rec[:confidence]
  end

  test "processing note changes when audio features disabled" do
    response = RecommendationResponse.new(
      seed_track: build_mock_track("Seed", "Artist"),
      seed_features: nil,
      recommendations: [],
      audio_features_enabled: false
    )

    metadata = response.to_h[:metadata]
    assert_equal false, metadata[:audio_features_enabled]
    assert metadata[:processing_note].include?("cultural similarity only")
  end

  test "seed features is nil when not provided" do
    response = RecommendationResponse.new(
      seed_track: build_mock_track("Seed", "Artist"),
      seed_features: nil,
      recommendations: [],
      audio_features_enabled: false
    )

    seed = response.to_h[:seed_track]
    assert_nil seed[:features]
  end

  test "handles nil seed track" do
    response = RecommendationResponse.new(
      seed_track: nil,
      seed_features: build_features,
      recommendations: [],
      audio_features_enabled: true
    )

    assert_nil response.to_h[:seed_track]
  end

  test "handles track without artists" do
    track_without_artists = OpenStruct.new(
      name: "Mystery Track",
      id: "track789",
      artists: nil,
      external_urls: { "spotify" => "https://open.spotify.com/track/track789" }
    )

    recommendations = [{
      spotify_track: track_without_artists,
      confidence: 0.5,
      reasons: ["Test"],
      breakdown: {}
    }]

    response = RecommendationResponse.new(
      seed_track: build_mock_track("Seed", "Artist"),
      seed_features: build_features,
      recommendations: recommendations,
      audio_features_enabled: true
    )

    rec = response.to_h[:recommendations].first
    assert_equal "Unknown Artist", rec[:track][:artist]
  end

  test "handles track with empty artists array" do
    track_empty_artists = OpenStruct.new(
      name: "Mystery Track",
      id: "track789",
      artists: [],
      external_urls: { "spotify" => "https://open.spotify.com/track/track789" }
    )

    recommendations = [{
      spotify_track: track_empty_artists,
      confidence: 0.5,
      reasons: ["Test"],
      breakdown: {}
    }]

    response = RecommendationResponse.new(
      seed_track: build_mock_track("Seed", "Artist"),
      seed_features: build_features,
      recommendations: recommendations,
      audio_features_enabled: true
    )

    rec = response.to_h[:recommendations].first
    assert_equal "Unknown Artist", rec[:track][:artist]
  end

  test "ranks recommendations correctly" do
    response = build_response
    recommendations = response.to_h[:recommendations]

    assert_equal 1, recommendations[0][:rank]
    assert_equal 2, recommendations[1][:rank]
  end

  private

  def build_response
    seed_track = build_mock_track("Sunset Lover", "Petit Biscuit", "seed123")
    seed_features = build_features

    recommendations = [
      build_recommendation(
        name: "Adventure",
        artist: "Madeon",
        track_id: "track456",
        confidence: 0.85,
        reasons: ["Harmonic Match", "Similar Tempo"]
      ),
      build_recommendation(
        name: "Shelter",
        artist: "Porter Robinson",
        track_id: "track789",
        confidence: 0.72,
        reasons: ["Culturally Similar"]
      )
    ]

    RecommendationResponse.new(
      seed_track: seed_track,
      seed_features: seed_features,
      recommendations: recommendations,
      audio_features_enabled: true
    )
  end

  def build_mock_track(name, artist, track_id = "track123")
    OpenStruct.new(
      name: name,
      id: track_id,
      artists: [OpenStruct.new(name: artist)],
      external_urls: { "spotify" => "https://open.spotify.com/track/#{track_id}" }
    )
  end

  def build_features
    AudioFeatures.new(
      tempo: 120,
      key: 0,
      mode: 1,
      energy: 0.8,
      valence: 0.6,
      danceability: 0.7
    )
  end

  def build_recommendation(name: "Track", artist: "Artist", track_id: "track123", confidence: 0.8, reasons: [])
    {
      spotify_track: build_mock_track(name, artist, track_id),
      confidence: confidence,
      reasons: reasons,
      breakdown: { cultural: 0.2, key: 0.25, tempo: 0.9 }
    }
  end
end
