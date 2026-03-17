# Calculates tempo compatibility between tracks for DJ-style mixing.
#
# Professional DJs match tempos to ensure smooth transitions. This class
# implements the standard DJ tempo matching rules:
#   - Same tempo (±10%): Tracks can be mixed directly
#   - Double tempo (2x): Common in genre transitions (e.g., house to drum & bass)
#   - Half tempo (0.5x): Beatdown transitions
#
# Usage:
#   matcher = TempoMatcher.new(120)        # Seed track at 120 BPM
#   matcher.similarity_score(118)          # => 0.9 (within 10%)
#   matcher.similarity_score(240)          # => 0.85 (double time)
#   matcher.describe_relationship(118)     # => "Near-perfect match"
#   matcher.describe_relationship(240)     # => "Double time"
#
class TempoMatcher
  # Acceptable tempo ratio ranges for smooth transitions
  SAME_TEMPO_TIGHT = (0.95..1.05)   # Near-perfect match
  SAME_TEMPO_LOOSE = (0.9..1.1)     # Standard DJ tolerance (±10%)
  DOUBLE_TEMPO_TIGHT = (1.95..2.05) # Near-perfect double time
  DOUBLE_TEMPO_LOOSE = (1.9..2.1)   # Double time with tolerance
  HALF_TEMPO_TIGHT = (0.48..0.52)   # Near-perfect half time
  HALF_TEMPO_LOOSE = (0.45..0.55)   # Half time with tolerance
  EXTENDED_RANGE = (0.8..1.2)       # Acceptable with pitch adjustment

  attr_reader :seed_bpm

  # @param seed_bpm [Numeric, nil] The tempo of the seed track in BPM
  def initialize(seed_bpm)
    @seed_bpm = seed_bpm&.to_f
  end

  # Calculates a similarity score between 0.0 and 1.0 for a candidate tempo.
  # Higher scores indicate better tempo compatibility.
  #
  # @param candidate_bpm [Numeric, nil] The tempo of the candidate track in BPM
  # @return [Float] Similarity score between 0.0 and 1.0
  def similarity_score(candidate_bpm)
    return 0.5 unless valid_tempos?(candidate_bpm)

    ratio = calculate_ratio(candidate_bpm)
    score_from_ratio(ratio)
  end

  # Returns a human-readable description of the tempo relationship.
  #
  # @param candidate_bpm [Numeric, nil] The tempo of the candidate track in BPM
  # @return [String] Description of the tempo relationship
  def describe_relationship(candidate_bpm)
    return "Unknown (missing tempo data)" unless valid_tempos?(candidate_bpm)

    ratio = calculate_ratio(candidate_bpm)

    case
    when SAME_TEMPO_TIGHT.cover?(ratio)
      "Near-perfect match"
    when SAME_TEMPO_LOOSE.cover?(ratio)
      "Same tempo (±10%)"
    when DOUBLE_TEMPO_LOOSE.cover?(ratio)
      "Double time"
    when HALF_TEMPO_LOOSE.cover?(ratio)
      "Half time"
    when EXTENDED_RANGE.cover?(ratio)
      "Mixable with pitch adjustment"
    else
      "Incompatible tempo"
    end
  end

  # Checks if the seed tempo is valid (non-nil and positive).
  #
  # @return [Boolean] true if seed tempo is valid
  def valid?
    @seed_bpm && @seed_bpm.positive?
  end

  private

  # Checks if both seed and candidate tempos are valid for comparison.
  def valid_tempos?(candidate_bpm)
    return false unless valid?
    return false if candidate_bpm.nil?

    candidate = candidate_bpm.to_f
    candidate.positive?
  end

  # Calculates the ratio between candidate and seed tempos.
  def calculate_ratio(candidate_bpm)
    candidate_bpm.to_f / @seed_bpm
  end

  # Converts a tempo ratio to a similarity score.
  # Uses a tiered scoring system based on DJ mixing conventions.
  def score_from_ratio(ratio)
    case
    when SAME_TEMPO_TIGHT.cover?(ratio)
      1.0
    when SAME_TEMPO_LOOSE.cover?(ratio)
      0.9
    when DOUBLE_TEMPO_TIGHT.cover?(ratio) || HALF_TEMPO_TIGHT.cover?(ratio)
      0.85
    when DOUBLE_TEMPO_LOOSE.cover?(ratio) || HALF_TEMPO_LOOSE.cover?(ratio)
      0.7
    when EXTENDED_RANGE.cover?(ratio)
      0.5
    else
      0.2
    end
  end
end
