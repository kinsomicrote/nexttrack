# Value object representing a track's audio characteristics.
#
# Encapsulates the audio analysis data retrieved from services like ReccoBeats
# or Spotify, providing normalized access and feature vector generation for
# similarity calculations.
#
# Usage:
#   features = AudioFeatures.new(
#     tempo: 120,
#     key: 0,
#     mode: 1,
#     energy: 0.8,
#     valence: 0.6,
#     danceability: 0.7
#   )
#
#   features.normalized_tempo        # => 0.5 (normalized to 0-1 scale)
#   features.to_vector               # => { tempo: 0.5, energy: 0.8, ... }
#   features.key_compatibility       # => KeyCompatibility instance
#
class AudioFeatures
  # BPM range for tempo normalization (typical music range)
  BPM_MIN = 60
  BPM_MAX = 180
  BPM_RANGE = (BPM_MAX - BPM_MIN).to_f

  # Default value for missing audio features (neutral/middle)
  DEFAULT_VALUE = 0.5

  attr_reader :tempo, :key, :mode, :energy, :valence, :danceability

  # @param tempo [Numeric, nil] Track tempo in BPM
  # @param key [Integer, nil] Pitch class (0-11, where C=0)
  # @param mode [Integer, nil] Mode (1 for major, 0 for minor)
  # @param energy [Float, nil] Energy level (0.0 to 1.0)
  # @param valence [Float, nil] Musical positiveness (0.0 to 1.0)
  # @param danceability [Float, nil] Danceability score (0.0 to 1.0)
  def initialize(tempo:, key:, mode:, energy:, valence:, danceability:)
    @tempo = tempo
    @key = key
    @mode = mode
    @energy = energy
    @valence = valence
    @danceability = danceability
  end

  # Returns the tempo normalized to a 0-1 scale.
  # Assumes typical music tempo range of 60-180 BPM.
  #
  # @return [Float] Normalized tempo between 0.0 and 1.0
  def normalized_tempo
    return DEFAULT_VALUE unless @tempo

    normalized = (@tempo.to_f - BPM_MIN) / BPM_RANGE
    [[normalized, 0.0].max, 1.0].min
  end

  # Returns the energy value, defaulting to 0.5 if not present.
  #
  # @return [Float] Energy value between 0.0 and 1.0
  def energy_or_default
    @energy || DEFAULT_VALUE
  end

  # Returns the valence value, defaulting to 0.5 if not present.
  #
  # @return [Float] Valence value between 0.0 and 1.0
  def valence_or_default
    @valence || DEFAULT_VALUE
  end

  # Returns the danceability value, defaulting to 0.5 if not present.
  #
  # @return [Float] Danceability value between 0.0 and 1.0
  def danceability_or_default
    @danceability || DEFAULT_VALUE
  end

  # Converts the audio features to a normalized vector for similarity calculations.
  #
  # @return [Hash] Feature vector with normalized values
  def to_vector
    {
      tempo: normalized_tempo,
      energy: energy_or_default,
      valence: valence_or_default,
      danceability: danceability_or_default
    }
  end

  # Creates a KeyCompatibility instance for this track's key.
  #
  # @return [KeyCompatibility] Key compatibility checker for this track
  def key_compatibility
    KeyCompatibility.new(@key, @mode)
  end

  # Creates a TempoMatcher instance for this track's tempo.
  #
  # @return [TempoMatcher] Tempo matcher for this track
  def tempo_matcher
    TempoMatcher.new(@tempo)
  end

  # Checks if this track has valid audio feature data.
  #
  # @return [Boolean] true if at least tempo or key data is present
  def valid?
    @tempo || @key
  end

  # Factory method to create AudioFeatures from a ReccoBeats API response.
  #
  # @param data [OpenStruct, Hash, nil] ReccoBeats audio features response
  # @return [AudioFeatures, nil] AudioFeatures instance or nil if data is invalid
  def self.from_recco_beats(data)
    return nil unless data

    # Check if it's a Hash-like object (use [] accessor) or OpenStruct-like (use method accessor)
    if data.is_a?(Hash)
      from_hash(data)
    else
      new(
        tempo: data.tempo,
        key: data.key,
        mode: data.mode,
        energy: data.energy,
        valence: data.valence,
        danceability: data.danceability
      )
    end
  end

  # Factory method to create AudioFeatures from a hash.
  #
  # @param hash [Hash] Hash with audio feature data
  # @return [AudioFeatures] AudioFeatures instance
  def self.from_hash(hash)
    new(
      tempo: hash[:tempo] || hash["tempo"],
      key: hash[:key] || hash["key"],
      mode: hash[:mode] || hash["mode"],
      energy: hash[:energy] || hash["energy"],
      valence: hash[:valence] || hash["valence"],
      danceability: hash[:danceability] || hash["danceability"]
    )
  end

  # Equality comparison for value object behavior.
  def ==(other)
    return false unless other.is_a?(AudioFeatures)

    @tempo == other.tempo &&
      @key == other.key &&
      @mode == other.mode &&
      @energy == other.energy &&
      @valence == other.valence &&
      @danceability == other.danceability
  end

  def eql?(other)
    self == other
  end

  def hash
    [@tempo, @key, @mode, @energy, @valence, @danceability].hash
  end
end
