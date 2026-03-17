# Encapsulates Circle of Fifths harmonic compatibility rules for DJ-style mixing.
#
# The Circle of Fifths defines which musical keys sound good together.
# For each key, compatible transitions include:
#   - Same key (no change)
#   - Dominant (perfect fifth above) - one step clockwise on the circle
#   - Subdominant (perfect fourth above) - one step counter-clockwise
#   - Relative major/minor - same key signature, different mode
#
# Usage:
#   seed_key = KeyCompatibility.new(0, 1)  # C Major
#   seed_key.compatible_with?(7, 1)        # => true (G Major is compatible)
#   seed_key.compatible_with?(6, 1)        # => false (F# Major is not compatible)
#   seed_key.name                          # => "C Major"
#
class KeyCompatibility
  # Pitch class to note name mapping (standard MIDI convention)
  PITCH_NAMES = %w[C C# D D# E F F# G G# A A# B].freeze

  # Maps each key/mode pair to its compatible transition targets.
  # Key format: [pitch_class, mode] where pitch_class is 0-11 and mode is 1 (major) or 0 (minor)
  COMPATIBLE_KEYS = {
    # --- MAJOR KEYS (Mode 1) ---
    # Each major key is compatible with: itself, dominant, subdominant, relative minor
    [0, 1]  => [[0, 1], [7, 1], [5, 1], [9, 0]],   # C Major   -> C, G, F, Am
    [1, 1]  => [[1, 1], [8, 1], [6, 1], [10, 0]],  # C# Major  -> C#, G#, F#, A#m
    [2, 1]  => [[2, 1], [9, 1], [7, 1], [11, 0]],  # D Major   -> D, A, G, Bm
    [3, 1]  => [[3, 1], [10, 1], [8, 1], [0, 0]],  # D# Major  -> D#, A#, G#, Cm
    [4, 1]  => [[4, 1], [11, 1], [9, 1], [1, 0]],  # E Major   -> E, B, A, C#m
    [5, 1]  => [[5, 1], [0, 1], [10, 1], [2, 0]],  # F Major   -> F, C, A#, Dm
    [6, 1]  => [[6, 1], [1, 1], [11, 1], [3, 0]],  # F# Major  -> F#, C#, B, D#m
    [7, 1]  => [[7, 1], [2, 1], [0, 1], [4, 0]],   # G Major   -> G, D, C, Em
    [8, 1]  => [[8, 1], [3, 1], [1, 1], [5, 0]],   # G# Major  -> G#, D#, C#, Fm
    [9, 1]  => [[9, 1], [4, 1], [2, 1], [6, 0]],   # A Major   -> A, E, D, F#m
    [10, 1] => [[10, 1], [5, 1], [3, 1], [7, 0]],  # A# Major  -> A#, F, D#, Gm
    [11, 1] => [[11, 1], [6, 1], [4, 1], [8, 0]],  # B Major   -> B, F#, E, G#m

    # --- MINOR KEYS (Mode 0) ---
    # Each minor key is compatible with: itself, dominant minor, subdominant minor, relative major
    [0, 0]  => [[0, 0], [7, 0], [5, 0], [3, 1]],   # C Minor   -> Cm, Gm, Fm, D#
    [1, 0]  => [[1, 0], [8, 0], [6, 0], [4, 1]],   # C# Minor  -> C#m, G#m, F#m, E
    [2, 0]  => [[2, 0], [9, 0], [7, 0], [5, 1]],   # D Minor   -> Dm, Am, Gm, F
    [3, 0]  => [[3, 0], [10, 0], [8, 0], [6, 1]],  # D# Minor  -> D#m, A#m, G#m, F#
    [4, 0]  => [[4, 0], [11, 0], [9, 0], [7, 1]],  # E Minor   -> Em, Bm, Am, G
    [5, 0]  => [[5, 0], [0, 0], [10, 0], [8, 1]],  # F Minor   -> Fm, Cm, A#m, G#
    [6, 0]  => [[6, 0], [1, 0], [11, 0], [9, 1]],  # F# Minor  -> F#m, C#m, Bm, A
    [7, 0]  => [[7, 0], [2, 0], [0, 0], [10, 1]],  # G Minor   -> Gm, Dm, Cm, A#
    [8, 0]  => [[8, 0], [3, 0], [1, 0], [11, 1]],  # G# Minor  -> G#m, D#m, C#m, B
    [9, 0]  => [[9, 0], [4, 0], [2, 0], [0, 1]],   # A Minor   -> Am, Em, Dm, C
    [10, 0] => [[10, 0], [5, 0], [3, 0], [1, 1]],  # A# Minor  -> A#m, Fm, D#m, C#
    [11, 0] => [[11, 0], [6, 0], [4, 0], [2, 1]]   # B Minor   -> Bm, F#m, Em, D
  }.freeze

  attr_reader :key, :mode

  # @param key [Integer, nil] Pitch class (0-11, where C=0, C#=1, etc.)
  # @param mode [Integer, nil] Mode (1 for major, 0 for minor)
  def initialize(key, mode)
    @key = key
    @mode = mode
  end

  # Checks if another key is harmonically compatible with this one.
  #
  # @param other_key [Integer, nil] Pitch class of the other key
  # @param other_mode [Integer, nil] Mode of the other key
  # @return [Boolean] true if the keys are compatible for mixing
  def compatible_with?(other_key, other_mode)
    return false if @key.nil? || @mode.nil?
    return false if other_key.nil? || other_mode.nil?

    allowed = COMPATIBLE_KEYS[[@key, @mode]]
    return false if allowed.nil?

    allowed.include?([other_key, other_mode])
  end

  # Returns the human-readable name of this key.
  #
  # @return [String] Key name (e.g., "C Major", "A Minor")
  def name
    return "Unknown" unless @key && @mode

    note = PITCH_NAMES[@key]
    mode_name = @mode == 1 ? "Major" : "Minor"
    "#{note} #{mode_name}"
  end

  # Checks if this key has valid data.
  #
  # @return [Boolean] true if both key and mode are present
  def valid?
    !@key.nil? && !@mode.nil?
  end

  # Returns all compatible keys as KeyCompatibility objects.
  #
  # @return [Array<KeyCompatibility>] List of compatible keys
  def compatible_keys
    return [] unless valid?

    allowed = COMPATIBLE_KEYS[[@key, @mode]] || []
    allowed.map { |k, m| KeyCompatibility.new(k, m) }
  end

  # Equality comparison for value object behavior.
  def ==(other)
    other.is_a?(KeyCompatibility) && @key == other.key && @mode == other.mode
  end

  def eql?(other)
    self == other
  end

  def hash
    [@key, @mode].hash
  end
end
