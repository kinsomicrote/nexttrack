require "test_helper"

class AudioFeaturesTest < ActiveSupport::TestCase
  test "initializes with all audio feature attributes" do
    features = AudioFeatures.new(
      tempo: 120,
      key: 0,
      mode: 1,
      energy: 0.8,
      valence: 0.6,
      danceability: 0.7
    )

    assert_equal 120, features.tempo
    assert_equal 0, features.key
    assert_equal 1, features.mode
    assert_equal 0.8, features.energy
    assert_equal 0.6, features.valence
    assert_equal 0.7, features.danceability
  end

  test "handles nil values gracefully" do
    features = AudioFeatures.new(
      tempo: nil,
      key: nil,
      mode: nil,
      energy: nil,
      valence: nil,
      danceability: nil
    )

    assert_nil features.tempo
    assert_nil features.key
    assert_nil features.mode
    assert_nil features.energy
    assert_nil features.valence
    assert_nil features.danceability
  end

  test "normalized_tempo returns 0.5 for 120 BPM (middle of range)" do
    features = build_features(tempo: 120)
    assert_equal 0.5, features.normalized_tempo
  end

  test "normalized_tempo returns 0.0 for 60 BPM (minimum)" do
    features = build_features(tempo: 60)
    assert_equal 0.0, features.normalized_tempo
  end

  test "normalized_tempo returns 1.0 for 180 BPM (maximum)" do
    features = build_features(tempo: 180)
    assert_equal 1.0, features.normalized_tempo
  end

  test "normalized_tempo clamps values below minimum to 0.0" do
    features = build_features(tempo: 40)
    assert_equal 0.0, features.normalized_tempo
  end

  test "normalized_tempo clamps values above maximum to 1.0" do
    features = build_features(tempo: 200)
    assert_equal 1.0, features.normalized_tempo
  end

  test "normalized_tempo returns 0.5 for nil tempo" do
    features = build_features(tempo: nil)
    assert_equal 0.5, features.normalized_tempo
  end

  test "normalized_tempo returns correct values for common BPMs" do
    assert_in_delta 0.25, build_features(tempo: 90).normalized_tempo, 0.01

    assert_in_delta 0.75, build_features(tempo: 150).normalized_tempo, 0.01
  end

  test "energy_or_default returns energy when present" do
    features = build_features(energy: 0.8)
    assert_equal 0.8, features.energy_or_default
  end

  test "energy_or_default returns 0.5 when nil" do
    features = build_features(energy: nil)
    assert_equal 0.5, features.energy_or_default
  end

  test "valence_or_default returns valence when present" do
    features = build_features(valence: 0.3)
    assert_equal 0.3, features.valence_or_default
  end

  test "valence_or_default returns 0.5 when nil" do
    features = build_features(valence: nil)
    assert_equal 0.5, features.valence_or_default
  end

  test "danceability_or_default returns danceability when present" do
    features = build_features(danceability: 0.9)
    assert_equal 0.9, features.danceability_or_default
  end

  test "danceability_or_default returns 0.5 when nil" do
    features = build_features(danceability: nil)
    assert_equal 0.5, features.danceability_or_default
  end

  test "to_vector returns hash with all normalized features" do
    features = AudioFeatures.new(
      tempo: 120,
      key: 0,
      mode: 1,
      energy: 0.8,
      valence: 0.6,
      danceability: 0.7
    )

    vector = features.to_vector

    assert_equal 0.5, vector[:tempo]
    assert_equal 0.8, vector[:energy]
    assert_equal 0.6, vector[:valence]
    assert_equal 0.7, vector[:danceability]
  end

  test "to_vector uses defaults for nil values" do
    features = AudioFeatures.new(
      tempo: nil,
      key: nil,
      mode: nil,
      energy: nil,
      valence: nil,
      danceability: nil
    )

    vector = features.to_vector

    assert_equal 0.5, vector[:tempo]
    assert_equal 0.5, vector[:energy]
    assert_equal 0.5, vector[:valence]
    assert_equal 0.5, vector[:danceability]
  end

  test "key_compatibility returns KeyCompatibility instance" do
    features = build_features(key: 0, mode: 1)
    key_compat = features.key_compatibility

    assert_instance_of KeyCompatibility, key_compat
    assert_equal 0, key_compat.key
    assert_equal 1, key_compat.mode
  end

  test "key_compatibility handles nil key/mode" do
    features = build_features(key: nil, mode: nil)
    key_compat = features.key_compatibility

    assert_instance_of KeyCompatibility, key_compat
    refute key_compat.valid?
  end

  test "tempo_matcher returns TempoMatcher instance" do
    features = build_features(tempo: 120)
    matcher = features.tempo_matcher

    assert_instance_of TempoMatcher, matcher
    assert_equal 120.0, matcher.seed_bpm
  end

  test "tempo_matcher handles nil tempo" do
    features = build_features(tempo: nil)
    matcher = features.tempo_matcher

    assert_instance_of TempoMatcher, matcher
    refute matcher.valid?
  end

  test "valid? returns true when tempo is present" do
    features = build_features(tempo: 120, key: nil)
    assert features.valid?
  end

  test "valid? returns true when key is present" do
    features = build_features(tempo: nil, key: 0)
    assert features.valid?
  end

  test "valid? returns false when both tempo and key are nil" do
    features = build_features(tempo: nil, key: nil)
    refute features.valid?
  end

  test "from_recco_beats creates instance from OpenStruct" do
    data = OpenStruct.new(
      tempo: 120,
      key: 0,
      mode: 1,
      energy: 0.8,
      valence: 0.6,
      danceability: 0.7
    )

    features = AudioFeatures.from_recco_beats(data)

    assert_equal 120, features.tempo
    assert_equal 0, features.key
    assert_equal 1, features.mode
    assert_equal 0.8, features.energy
  end

  test "from_recco_beats creates instance from Hash" do
    data = {
      tempo: 120,
      key: 0,
      mode: 1,
      energy: 0.8,
      valence: 0.6,
      danceability: 0.7
    }

    features = AudioFeatures.from_recco_beats(data)

    assert_equal 120, features.tempo
    assert_equal 0, features.key
  end

  test "from_recco_beats returns nil for nil data" do
    assert_nil AudioFeatures.from_recco_beats(nil)
  end

  test "from_hash creates instance from symbol keys" do
    hash = { tempo: 120, key: 0, mode: 1, energy: 0.8, valence: 0.6, danceability: 0.7 }
    features = AudioFeatures.from_hash(hash)

    assert_equal 120, features.tempo
    assert_equal 0, features.key
  end

  test "from_hash creates instance from string keys" do
    hash = { "tempo" => 120, "key" => 0, "mode" => 1, "energy" => 0.8, "valence" => 0.6, "danceability" => 0.7 }
    features = AudioFeatures.from_hash(hash)

    assert_equal 120, features.tempo
    assert_equal 0, features.key
  end

  test "equality works for identical features" do
    features1 = build_features(tempo: 120, key: 0, mode: 1, energy: 0.8)
    features2 = build_features(tempo: 120, key: 0, mode: 1, energy: 0.8)

    assert_equal features1, features2
  end

  test "inequality works for different features" do
    features1 = build_features(tempo: 120)
    features2 = build_features(tempo: 130)

    refute_equal features1, features2
  end

  test "hash is consistent for equal objects" do
    features1 = build_features(tempo: 120, key: 0)
    features2 = build_features(tempo: 120, key: 0)

    assert_equal features1.hash, features2.hash
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
