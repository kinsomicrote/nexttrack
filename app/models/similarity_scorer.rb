# Calculates similarity scores between a seed track and candidate tracks.
#
# Uses a multimodal approach combining:
#   - Cultural similarity (from MusicBrainz tags)
#   - Audio feature similarity (cosine similarity of feature vectors)
#   - Key compatibility (Circle of Fifths harmonic rules)
#   - Tempo compatibility (DJ mixing conventions)
#   - User target matching (optional energy/valence preferences)
#
# Usage:
#   seed_features = AudioFeatures.new(tempo: 120, key: 0, mode: 1, ...)
#   scorer = SimilarityScorer.new(seed_features, user_targets: { energy: 0.8 })
#
#   candidate_features = AudioFeatures.new(tempo: 118, key: 7, mode: 1, ...)
#   result = scorer.score(candidate_features)
#   # => { similarity: 0.85, confidence: 85.0, reasons: [...], breakdown: {...} }
#
class SimilarityScorer
  # Weights for combining different similarity dimensions
  WEIGHTS = {
    cultural: 0.15,    # Base weight for MusicBrainz cultural similarity
    audio: 0.30,       # Weight for audio feature cosine similarity
    key: 0.25,         # Weight for harmonic compatibility (not multiplied, added directly)
    tempo: 0.20,       # Weight for tempo compatibility
    target: 0.10       # Weight for user target matching
  }.freeze

  # Feature weights for cosine similarity calculation
  FEATURE_WEIGHTS = {
    tempo: 0.30,
    energy: 0.30,
    valence: 0.20,
    danceability: 0.20
  }.freeze

  # Base cultural similarity score for candidates from MusicBrainz
  BASE_CULTURAL_SCORE = 0.2

  # Key compatibility bonus (added directly, not weighted)
  KEY_COMPATIBILITY_BONUS = 0.25

  # Tolerance for user target matching (±0.2)
  TARGET_TOLERANCE = 0.2

  attr_reader :seed_features, :user_targets

  # @param seed_features [AudioFeatures, nil] Audio features of the seed track
  # @param user_targets [Hash] Optional user-specified targets (energy, valence, danceability)
  def initialize(seed_features, user_targets: {})
    @seed_features = seed_features
    @user_targets = normalize_targets(user_targets)
    @tempo_matcher = seed_features&.tempo_matcher
  end

  # Calculates a similarity score for a candidate track.
  #
  # @param candidate_features [AudioFeatures, nil] Audio features of the candidate
  # @return [Hash] Score result with :similarity, :confidence, :reasons, :breakdown
  def score(candidate_features)
    breakdown = { cultural: BASE_CULTURAL_SCORE }
    reasons = ["Culturally Similar"]

    if @seed_features && candidate_features
      add_audio_scores(candidate_features, breakdown, reasons)
    end

    total = calculate_total(breakdown)

    {
      similarity: total,
      confidence: [total, 1.0].min,
      reasons: reasons,
      breakdown: format_breakdown(breakdown)
    }
  end

  private

  # Normalizes user targets to a consistent format.
  def normalize_targets(targets)
    return {} if targets.nil?

    targets.transform_keys(&:to_s)
  end

  # Adds audio-based scores to the breakdown.
  def add_audio_scores(candidate, breakdown, reasons)
    # Key compatibility
    breakdown[:key] = calculate_key_score(candidate, reasons)

    # Tempo similarity
    breakdown[:tempo] = calculate_tempo_score(candidate, reasons)

    # Audio feature cosine similarity
    breakdown[:audio] = calculate_audio_similarity(candidate)

    # User target matching
    breakdown[:target] = calculate_target_score(candidate, reasons)
  end

  # Calculates key compatibility score.
  def calculate_key_score(candidate, reasons)
    seed_key = @seed_features.key_compatibility

    if seed_key.compatible_with?(candidate.key, candidate.mode)
      candidate_key = KeyCompatibility.new(candidate.key, candidate.mode)
      reasons << "Harmonic Match (#{candidate_key.name})"
      KEY_COMPATIBILITY_BONUS
    else
      0.0
    end
  end

  # Calculates tempo compatibility score.
  def calculate_tempo_score(candidate, reasons)
    return 0.5 unless @tempo_matcher&.valid?

    score = @tempo_matcher.similarity_score(candidate.tempo)
    reasons << "Tempo: #{@tempo_matcher.describe_relationship(candidate.tempo)}" if score > 0.5
    score
  end

  # Calculates cosine similarity between feature vectors.
  def calculate_audio_similarity(candidate)
    seed_vector = @seed_features.to_vector
    candidate_vector = candidate.to_vector

    cosine_similarity(seed_vector, candidate_vector)
  end

  # Computes weighted cosine similarity between two feature vectors.
  def cosine_similarity(vec1, vec2)
    return 0.0 unless vec1 && vec2

    dot_product = 0.0
    magnitude1 = 0.0
    magnitude2 = 0.0

    FEATURE_WEIGHTS.each do |feature, weight|
      v1 = (vec1[feature] || 0.5) * weight
      v2 = (vec2[feature] || 0.5) * weight

      dot_product += v1 * v2
      magnitude1 += v1 * v1
      magnitude2 += v2 * v2
    end

    return 0.0 if magnitude1.zero? || magnitude2.zero?

    dot_product / (Math.sqrt(magnitude1) * Math.sqrt(magnitude2))
  end

  # Calculates how well candidate matches user-specified targets.
  def calculate_target_score(candidate, reasons)
    return 0.0 if @user_targets.empty?

    scores = []

    %w[energy valence danceability].each do |attr|
      next unless @user_targets[attr]

      target = @user_targets[attr].to_f
      actual = candidate.send(attr)&.to_f || 0.5

      # Score based on distance (closer = higher score)
      distance = (target - actual).abs
      scores << [1.0 - (distance / TARGET_TOLERANCE), 0.0].max
    end

    return 0.0 if scores.empty?

    avg_score = scores.sum / scores.length
    reasons << "Matches Targets" if avg_score > 0.5
    avg_score
  end

  # Calculates the total weighted score.
  def calculate_total(breakdown)
    # Cultural and audio are multiplied by their weights
    # Key is added directly (it's a bonus)
    # Tempo and target are multiplied by their weights
    breakdown[:cultural] * WEIGHTS[:cultural] +
      (breakdown[:audio] || 0) * WEIGHTS[:audio] +
      (breakdown[:key] || 0) +  # Direct addition, not weighted
      (breakdown[:tempo] || 0) * WEIGHTS[:tempo] +
      (breakdown[:target] || 0) * WEIGHTS[:target]
  end

  # Formats breakdown values for output.
  def format_breakdown(breakdown)
    breakdown.transform_values { |v| v.is_a?(Float) ? v.round(3) : v }
  end
end
