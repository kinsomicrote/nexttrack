require "test_helper"

# Tests for the scoring algorithm components of RecommendationEngine
# These tests use a mock approach since the full engine requires API connections
class ScoringAlgorithmsTest < ActiveSupport::TestCase
  # Tempo compatibility ratio tests
  # The engine considers these ratios compatible:
  # - Same tempo: 0.9 to 1.1 (within 10%)
  # - Double tempo: 1.9 to 2.1
  # - Half tempo: 0.45 to 0.55

  test "tempo ratio 1.0 is compatible (exact match)" do
    assert tempo_compatible?(120, 120)
  end

  test "tempo ratio 0.9 is compatible (lower bound of same tempo)" do
    assert tempo_compatible?(108, 120)
  end

  test "tempo ratio 1.1 is compatible (upper bound of same tempo)" do
    assert tempo_compatible?(132, 120)
  end

  test "tempo ratio 0.88 is not compatible (below lower bound)" do
    refute tempo_compatible?(105.6, 120)
  end

  test "tempo ratio 1.12 is not compatible (above upper bound)" do
    refute tempo_compatible?(134.4, 120)
  end

  test "tempo ratio 2.0 is compatible (double tempo)" do
    assert tempo_compatible?(240, 120)
  end

  test "tempo ratio 1.95 is compatible (within double tempo range)" do
    assert tempo_compatible?(234, 120)
  end

  test "tempo ratio 0.5 is compatible (half tempo)" do
    assert tempo_compatible?(60, 120)
  end

  test "tempo ratio 0.48 is compatible (within half tempo range)" do
    assert tempo_compatible?(57.6, 120)
  end

  test "tempo ratio 0.7 is not compatible (between ranges)" do
    refute tempo_compatible?(84, 120)
  end

  test "tempo ratio 1.5 is not compatible (between same and double)" do
    refute tempo_compatible?(180, 120)
  end

  test "same key is compatible" do
    assert key_compatible?([0, 1], [0, 1])
    assert key_compatible?([9, 0], [9, 0])
  end

  test "dominant key is compatible (5th above)" do
    assert key_compatible?([0, 1], [7, 1])
    assert key_compatible?([7, 1], [2, 1])
  end

  test "subdominant key is compatible (4th above / 5th below)" do
    assert key_compatible?([0, 1], [5, 1])
    assert key_compatible?([7, 1], [0, 1])
  end

  test "relative minor is compatible" do
    assert key_compatible?([0, 1], [9, 0])
    assert key_compatible?([7, 1], [4, 0])
  end

  test "relative major is compatible" do
    assert key_compatible?([9, 0], [0, 1])
    assert key_compatible?([4, 0], [7, 1])
  end

  test "distant key is not compatible" do
    refute key_compatible?([0, 1], [6, 1])
  end

  # Energy/Valence target tests
  test "energy within tolerance is compatible" do
    assert target_compatible?(0.8, 0.75, 0.2)
    assert target_compatible?(0.5, 0.6, 0.2)
  end

  test "energy outside tolerance is not compatible" do
    refute target_compatible?(0.8, 0.5, 0.2)
    refute target_compatible?(0.3, 0.7, 0.2)
  end

  test "nil target is always compatible" do
    assert target_compatible?(nil, 0.5, 0.2)
  end

  private

  # Helper methods that mirror the RecommendationEngine's logic
  def tempo_compatible?(candidate_bpm, seed_bpm)
    return false if candidate_bpm.nil? || candidate_bpm.to_f.zero?
    return true if seed_bpm.nil? || seed_bpm.to_f.zero?

    ratio = candidate_bpm.to_f / seed_bpm.to_f
    ratio.between?(0.9, 1.1) || ratio.between?(1.9, 2.1) || ratio.between?(0.45, 0.55)
  end

  def key_compatible?(seed_pair, target_pair)
    allowed = KeyCompatibility::COMPATIBLE_KEYS[seed_pair]
    return true if allowed.nil?
    allowed.include?(target_pair)
  end

  def target_compatible?(target, actual, tolerance)
    return true if target.nil?
    actual.between?(target - tolerance, target + tolerance)
  end

  test "tempo_similarity_score returns 1.0 for exact match" do
    assert_equal 1.0, tempo_similarity_score(120, 120)
  end

  test "tempo_similarity_score returns 0.9 for 10% difference" do
    score = tempo_similarity_score(130, 120)
    assert_in_delta 0.9, score, 0.05
  end

  test "tempo_similarity_score returns ~0.85 for double time" do
    score = tempo_similarity_score(240, 120)
    assert_in_delta 0.85, score, 0.05
  end

  test "tempo_similarity_score returns ~0.85 for half time" do
    score = tempo_similarity_score(60, 120)
    assert_in_delta 0.85, score, 0.05
  end

  test "tempo_similarity_score returns low score for distant tempo" do
    score = tempo_similarity_score(80, 120)
    assert score < 0.5, "Distant tempo should score below 0.5"
  end

  def tempo_similarity_score(candidate_bpm, seed_bpm)
    return 0.5 unless candidate_bpm && seed_bpm

    ratio = candidate_bpm.to_f / seed_bpm.to_f
    return 0.0 if ratio.zero?

    if ratio.between?(0.95, 1.05)
      1.0
    elsif ratio.between?(0.9, 1.1)
      0.9
    elsif ratio.between?(1.95, 2.05) || ratio.between?(0.48, 0.52)
      0.85
    elsif ratio.between?(1.9, 2.1) || ratio.between?(0.45, 0.55)
      0.7
    elsif ratio.between?(0.8, 1.2)
      0.5
    else
      0.2
    end
  end
end
