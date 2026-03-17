require "test_helper"

class RecommendationEngineTest < ActiveSupport::TestCase
  test "COMPATIBLE_KEYS covers all 24 key/mode combinations" do
    assert_equal 24, KeyCompatibility::COMPATIBLE_KEYS.keys.length

    (0..11).each do |pitch|
      assert KeyCompatibility::COMPATIBLE_KEYS.key?([pitch, 1]),
             "Missing major key for pitch class #{pitch}"
    end

    (0..11).each do |pitch|
      assert KeyCompatibility::COMPATIBLE_KEYS.key?([pitch, 0]),
             "Missing minor key for pitch class #{pitch}"
    end
  end

  test "each key has exactly 4 compatible keys" do
    KeyCompatibility::COMPATIBLE_KEYS.each do |key, compatible|
      assert_equal 4, compatible.length,
             "Key #{key.inspect} should have exactly 4 compatible keys, has #{compatible.length}"
    end
  end

  test "compatible keys include the key itself (same key is compatible)" do
    KeyCompatibility::COMPATIBLE_KEYS.each do |key, compatible|
      assert_includes compatible, key,
                      "Key #{key.inspect} should include itself as compatible"
    end
  end

  test "C major compatible with G major (dominant), F major (subdominant), A minor (relative)" do
    c_major = [0, 1]
    compatible = KeyCompatibility::COMPATIBLE_KEYS[c_major]

    assert_includes compatible, [0, 1], "C major should be compatible with itself"
    assert_includes compatible, [7, 1], "C major should be compatible with G major (dominant)"
    assert_includes compatible, [5, 1], "C major should be compatible with F major (subdominant)"
    assert_includes compatible, [9, 0], "C major should be compatible with A minor (relative)"
  end

  test "A minor compatible with E minor (dominant), D minor (subdominant), C major (relative)" do
    a_minor = [9, 0]
    compatible = KeyCompatibility::COMPATIBLE_KEYS[a_minor]

    assert_includes compatible, [9, 0], "A minor should be compatible with itself"
    assert_includes compatible, [4, 0], "A minor should be compatible with E minor (dominant)"
    assert_includes compatible, [2, 0], "A minor should be compatible with D minor (subdominant)"
    assert_includes compatible, [0, 1], "A minor should be compatible with C major (relative)"
  end

  # Test FEATURE_WEIGHTS
  test "FEATURE_WEIGHTS contains all required audio features" do
    weights = SimilarityScorer::FEATURE_WEIGHTS

    assert weights.key?(:tempo), "Should have tempo weight"
    assert weights.key?(:energy), "Should have energy weight"
    assert weights.key?(:valence), "Should have valence weight"
    assert weights.key?(:danceability), "Should have danceability weight"
  end

  test "FEATURE_WEIGHTS values are between 0 and 1" do
    SimilarityScorer::FEATURE_WEIGHTS.each do |feature, weight|
      assert weight >= 0 && weight <= 1,
             "Feature weight for #{feature} should be between 0 and 1, got #{weight}"
    end
  end

  test "FEATURE_WEIGHTS sum to 1.0" do
    total = SimilarityScorer::FEATURE_WEIGHTS.values.sum
    assert_in_delta 1.0, total, 0.01, "Feature weights should sum to 1.0"
  end

  test "Circle of Fifths progression - major keys clockwise" do
    circle = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]

    circle.each_cons(2) do |current, next_key|
      compatible = KeyCompatibility::COMPATIBLE_KEYS[[current, 1]]
      assert_includes compatible, [next_key, 1],
                      "#{pitch_name(current)} major should be compatible with #{pitch_name(next_key)} major (5th)"
    end
  end

  test "relative major/minor relationships" do
    relatives = {
      [0, 1] => [9, 0],
      [7, 1] => [4, 0],
      [2, 1] => [11, 0],
      [5, 1] => [2, 0],
    }

    relatives.each do |major, minor|
      compatible = KeyCompatibility::COMPATIBLE_KEYS[major]
      assert_includes compatible, minor,
                      "#{pitch_name(major[0])} major should be compatible with its relative minor"
    end
  end

  test "MAX_SCORE is defined as 1.0 for normalized scoring" do
    assert_equal 1.0, RecommendationEngine::MAX_SCORE
  end

  private

  def pitch_name(pitch_class)
    names = %w[C C# D D# E F F# G G# A A# B]
    names[pitch_class]
  end
end
