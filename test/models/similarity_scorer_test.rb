require "test_helper"

class SimilarityScorerTest < ActiveSupport::TestCase

  test "initializes with seed features" do
    seed = build_features(tempo: 120, key: 0, mode: 1)
    scorer = SimilarityScorer.new(seed)

    assert_equal seed, scorer.seed_features
  end

  test "initializes with user targets" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8 })

    assert_equal({ "energy" => 0.8 }, scorer.user_targets)
  end

  test "handles nil seed features" do
    scorer = SimilarityScorer.new(nil)

    assert_nil scorer.seed_features
  end

  test "normalizes string and symbol keys in user targets" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8, "valence" => 0.5 })

    assert_equal 0.8, scorer.user_targets["energy"]
    assert_equal 0.5, scorer.user_targets["valence"]
  end

  test "score returns hash with required keys" do
    seed = build_features
    scorer = SimilarityScorer.new(seed)
    candidate = build_features

    result = scorer.score(candidate)

    assert result.key?(:similarity)
    assert result.key?(:confidence)
    assert result.key?(:reasons)
    assert result.key?(:breakdown)
  end

  test "score includes cultural similarity reason" do
    seed = build_features
    scorer = SimilarityScorer.new(seed)
    candidate = build_features

    result = scorer.score(candidate)

    assert_includes result[:reasons], "Culturally Similar"
  end

  test "score breakdown includes cultural score" do
    seed = build_features
    scorer = SimilarityScorer.new(seed)
    candidate = build_features

    result = scorer.score(candidate)

    assert_equal 0.2, result[:breakdown][:cultural]
  end

  test "compatible key adds bonus and reason" do
    seed = build_features(key: 0, mode: 1)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(key: 7, mode: 1)

    result = scorer.score(candidate)

    assert_equal 0.25, result[:breakdown][:key]
    assert result[:reasons].any? { |r| r.include?("Harmonic Match") }
  end

  test "incompatible key gets zero bonus" do
    seed = build_features(key: 0, mode: 1)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(key: 6, mode: 1)

    result = scorer.score(candidate)

    assert_equal 0.0, result[:breakdown][:key]
    refute result[:reasons].any? { |r| r.include?("Harmonic Match") }
  end

  test "same key adds bonus" do
    seed = build_features(key: 0, mode: 1)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(key: 0, mode: 1)

    result = scorer.score(candidate)

    assert_equal 0.25, result[:breakdown][:key]
  end

  test "relative minor adds bonus" do
    seed = build_features(key: 0, mode: 1)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(key: 9, mode: 0)

    result = scorer.score(candidate)

    assert_equal 0.25, result[:breakdown][:key]
  end

  test "same tempo scores high" do
    seed = build_features(tempo: 120)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 120)

    result = scorer.score(candidate)

    assert_equal 1.0, result[:breakdown][:tempo]
  end

  test "similar tempo scores well" do
    seed = build_features(tempo: 120)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 125)

    result = scorer.score(candidate)

    assert result[:breakdown][:tempo] >= 0.9
  end

  test "double tempo scores reasonably" do
    seed = build_features(tempo: 120)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 240)

    result = scorer.score(candidate)

    assert result[:breakdown][:tempo] >= 0.7
  end

  test "half tempo scores reasonably" do
    seed = build_features(tempo: 120)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 60)

    result = scorer.score(candidate)

    assert result[:breakdown][:tempo] >= 0.7
  end

  test "distant tempo scores low" do
    seed = build_features(tempo: 120)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 80)

    result = scorer.score(candidate)

    assert result[:breakdown][:tempo] < 0.5
  end

  test "tempo reason included when score > 0.5" do
    seed = build_features(tempo: 120)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 118)

    result = scorer.score(candidate)

    assert result[:reasons].any? { |r| r.include?("Tempo:") }
  end

  test "identical features have high audio similarity" do
    seed = build_features(tempo: 120, energy: 0.8, valence: 0.6, danceability: 0.7)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 120, energy: 0.8, valence: 0.6, danceability: 0.7)

    result = scorer.score(candidate)

    assert result[:breakdown][:audio] > 0.95
  end

  test "similar features have good audio similarity" do
    seed = build_features(tempo: 120, energy: 0.8, valence: 0.6, danceability: 0.7)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 125, energy: 0.75, valence: 0.55, danceability: 0.65)

    result = scorer.score(candidate)

    assert result[:breakdown][:audio] > 0.8
  end

  test "different features have lower audio similarity" do
    seed = build_features(tempo: 120, energy: 0.9, valence: 0.8, danceability: 0.9)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 80, energy: 0.2, valence: 0.3, danceability: 0.2)

    result = scorer.score(candidate)

    assert result[:breakdown][:audio] < 0.99
  end

  test "exact target match scores high" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8 })
    candidate = build_features(energy: 0.8)

    result = scorer.score(candidate)

    assert result[:breakdown][:target] >= 0.9
  end

  test "target within tolerance scores well" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8 })
    candidate = build_features(energy: 0.75)

    result = scorer.score(candidate)

    assert result[:breakdown][:target] >= 0.5
  end

  test "target outside tolerance scores zero" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8 })
    candidate = build_features(energy: 0.3)

    result = scorer.score(candidate)

    assert result[:breakdown][:target] < 0.5
  end

  test "multiple targets are averaged" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8, valence: 0.6 })
    candidate = build_features(energy: 0.8, valence: 0.6)

    result = scorer.score(candidate)

    assert result[:breakdown][:target] >= 0.9
  end

  test "no targets results in zero target score" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: {})
    candidate = build_features

    result = scorer.score(candidate)

    assert_equal 0.0, result[:breakdown][:target]
  end

  test "target match reason included when score > 0.5" do
    seed = build_features
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8 })
    candidate = build_features(energy: 0.8)

    result = scorer.score(candidate)

    assert_includes result[:reasons], "Matches Targets"
  end

  test "perfect match has high total score" do
    seed = build_features(tempo: 120, key: 0, mode: 1, energy: 0.8, valence: 0.6, danceability: 0.7)
    scorer = SimilarityScorer.new(seed, user_targets: { energy: 0.8 })
    candidate = build_features(tempo: 120, key: 0, mode: 1, energy: 0.8, valence: 0.6, danceability: 0.7)

    result = scorer.score(candidate)

    assert result[:similarity] > 0.8
  end

  test "compatible candidate has moderate score" do
    seed = build_features(tempo: 120, key: 0, mode: 1)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 125, key: 7, mode: 1)
    result = scorer.score(candidate)

    assert result[:similarity] > 0.5
  end

  test "incompatible candidate has lower score" do
    seed = build_features(tempo: 120, key: 0, mode: 1)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 80, key: 6, mode: 1)

    result = scorer.score(candidate)

    assert result[:similarity] < 0.5
  end

  test "confidence is capped at 1.0" do
    seed = build_features
    scorer = SimilarityScorer.new(seed)
    candidate = build_features

    result = scorer.score(candidate)

    assert result[:confidence] <= 1.0
  end

  test "confidence equals similarity when under 1.0" do
    seed = build_features
    scorer = SimilarityScorer.new(seed)
    candidate = build_features

    result = scorer.score(candidate)

    if result[:similarity] < 1.0
      assert_equal result[:similarity], result[:confidence]
    end
  end

  test "nil seed features returns cultural-only score" do
    scorer = SimilarityScorer.new(nil)
    candidate = build_features

    result = scorer.score(candidate)

    assert_equal 0.2, result[:breakdown][:cultural]
    assert_nil result[:breakdown][:key]
    assert_nil result[:breakdown][:tempo]
  end

  test "nil candidate features returns cultural-only score" do
    seed = build_features
    scorer = SimilarityScorer.new(seed)

    result = scorer.score(nil)

    assert_equal 0.2, result[:breakdown][:cultural]
  end

  test "breakdown values are rounded to 3 decimal places" do
    seed = build_features(tempo: 123)
    scorer = SimilarityScorer.new(seed)
    candidate = build_features(tempo: 127)

    result = scorer.score(candidate)

    result[:breakdown].each do |key, value|
      next unless value.is_a?(Float)

      assert_equal value, value.round(3), "#{key} should be rounded to 3 decimals"
    end
  end

  private

  def build_features(tempo: 120, key: 0, mode: 1, energy: 0.8, valence: 0.6, danceability: 0.7)
    AudioFeatures.new(
      tempo: tempo,
      key: key,
      mode: mode,
      energy: energy,
      valence: valence,
      danceability: danceability
    )
  end
end
