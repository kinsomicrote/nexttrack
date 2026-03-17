require "test_helper"

class KeyCompatibilityTest < ActiveSupport::TestCase

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

  test "every key includes itself as compatible" do
    KeyCompatibility::COMPATIBLE_KEYS.each do |key, compatible|
      assert_includes compatible, key,
                      "Key #{key.inspect} should include itself as compatible"
    end
  end

  test "initializes with key and mode" do
    key = KeyCompatibility.new(0, 1)

    assert_equal 0, key.key
    assert_equal 1, key.mode
  end

  test "handles nil key" do
    key = KeyCompatibility.new(nil, 1)

    assert_nil key.key
    assert_equal 1, key.mode
    refute key.valid?
  end

  test "handles nil mode" do
    key = KeyCompatibility.new(0, nil)

    assert_equal 0, key.key
    assert_nil key.mode
    refute key.valid?
  end

  test "name returns correct major key names" do
    assert_equal "C Major", KeyCompatibility.new(0, 1).name
    assert_equal "G Major", KeyCompatibility.new(7, 1).name
    assert_equal "F# Major", KeyCompatibility.new(6, 1).name
  end

  test "name returns correct minor key names" do
    assert_equal "A Minor", KeyCompatibility.new(9, 0).name
    assert_equal "E Minor", KeyCompatibility.new(4, 0).name
    assert_equal "C# Minor", KeyCompatibility.new(1, 0).name
  end

  test "name returns Unknown for invalid keys" do
    assert_equal "Unknown", KeyCompatibility.new(nil, 1).name
    assert_equal "Unknown", KeyCompatibility.new(0, nil).name
    assert_equal "Unknown", KeyCompatibility.new(nil, nil).name
  end

  test "same key is always compatible" do
    (0..11).each do |pitch|
      [0, 1].each do |mode|
        key = KeyCompatibility.new(pitch, mode)
        assert key.compatible_with?(pitch, mode),
               "#{key.name} should be compatible with itself"
      end
    end
  end

  test "C major compatible with G major (dominant)" do
    c_major = KeyCompatibility.new(0, 1)
    assert c_major.compatible_with?(7, 1)
  end

  test "C major compatible with F major (subdominant)" do
    c_major = KeyCompatibility.new(0, 1)
    assert c_major.compatible_with?(5, 1)
  end

  test "C major compatible with A minor (relative)" do
    c_major = KeyCompatibility.new(0, 1)
    assert c_major.compatible_with?(9, 0)
  end

  test "G major compatible with D major (dominant)" do
    g_major = KeyCompatibility.new(7, 1)
    assert g_major.compatible_with?(2, 1)
  end

  test "G major compatible with C major (subdominant)" do
    g_major = KeyCompatibility.new(7, 1)
    assert g_major.compatible_with?(0, 1)
  end

  test "G major compatible with E minor (relative)" do
    g_major = KeyCompatibility.new(7, 1)
    assert g_major.compatible_with?(4, 0)
  end

  test "A minor compatible with E minor (dominant)" do
    a_minor = KeyCompatibility.new(9, 0)
    assert a_minor.compatible_with?(4, 0)
  end

  test "A minor compatible with D minor (subdominant)" do
    a_minor = KeyCompatibility.new(9, 0)
    assert a_minor.compatible_with?(2, 0)
  end

  test "A minor compatible with C major (relative)" do
    a_minor = KeyCompatibility.new(9, 0)
    assert a_minor.compatible_with?(0, 1)
  end

  test "C major NOT compatible with F# major (tritone)" do
    c_major = KeyCompatibility.new(0, 1)
    refute c_major.compatible_with?(6, 1)
  end

  test "C major NOT compatible with C# major (semitone)" do
    c_major = KeyCompatibility.new(0, 1)
    refute c_major.compatible_with?(1, 1)
  end

  test "A minor NOT compatible with D# minor (tritone)" do
    a_minor = KeyCompatibility.new(9, 0)
    refute a_minor.compatible_with?(3, 0)
  end

  test "nil seed key is not compatible with anything" do
    key = KeyCompatibility.new(nil, 1)
    refute key.compatible_with?(0, 1)
    refute key.compatible_with?(6, 0)
  end

  test "nil seed mode is not compatible with anything" do
    key = KeyCompatibility.new(0, nil)
    refute key.compatible_with?(0, 1)
    refute key.compatible_with?(6, 0)
  end

  test "any key is not compatible with nil target" do
    key = KeyCompatibility.new(0, 1)
    refute key.compatible_with?(nil, 1)
    refute key.compatible_with?(0, nil)
    refute key.compatible_with?(nil, nil)
  end

  test "Circle of Fifths clockwise progression - major keys" do
    circle = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]

    circle.each_cons(2) do |current_pitch, next_pitch|
      current_key = KeyCompatibility.new(current_pitch, 1)
      assert current_key.compatible_with?(next_pitch, 1),
             "#{current_key.name} should be compatible with #{KeyCompatibility.new(next_pitch, 1).name} (dominant)"
    end
  end

  test "relative major/minor pairs are mutually compatible" do
    relatives = {
      [0, 1] => [9, 0],
      [7, 1] => [4, 0],
      [2, 1] => [11, 0],
      [5, 1] => [2, 0],
      [9, 1] => [6, 0],
    }

    relatives.each do |(major_pitch, major_mode), (minor_pitch, minor_mode)|
      major_key = KeyCompatibility.new(major_pitch, major_mode)
      minor_key = KeyCompatibility.new(minor_pitch, minor_mode)

      assert major_key.compatible_with?(minor_pitch, minor_mode),
             "#{major_key.name} should be compatible with #{minor_key.name}"
      assert minor_key.compatible_with?(major_pitch, major_mode),
             "#{minor_key.name} should be compatible with #{major_key.name}"
    end
  end

  test "valid? returns true when both key and mode present" do
    assert KeyCompatibility.new(0, 1).valid?
    assert KeyCompatibility.new(11, 0).valid?
  end

  test "valid? returns false when key or mode missing" do
    refute KeyCompatibility.new(nil, 1).valid?
    refute KeyCompatibility.new(0, nil).valid?
    refute KeyCompatibility.new(nil, nil).valid?
  end

  test "equality works for same key/mode" do
    key1 = KeyCompatibility.new(0, 1)
    key2 = KeyCompatibility.new(0, 1)

    assert_equal key1, key2
  end

  test "inequality works for different keys" do
    key1 = KeyCompatibility.new(0, 1)
    key2 = KeyCompatibility.new(7, 1)

    refute_equal key1, key2
  end

  test "compatible_keys returns array of KeyCompatibility objects" do
    c_major = KeyCompatibility.new(0, 1)
    compatible = c_major.compatible_keys

    assert_equal 4, compatible.length
    assert compatible.all? { |k| k.is_a?(KeyCompatibility) }
    assert_includes compatible, KeyCompatibility.new(0, 1)
    assert_includes compatible, KeyCompatibility.new(7, 1)
    assert_includes compatible, KeyCompatibility.new(5, 1)
    assert_includes compatible, KeyCompatibility.new(9, 0)
  end

  test "compatible_keys returns empty array for invalid key" do
    invalid = KeyCompatibility.new(nil, 1)
    assert_empty invalid.compatible_keys
  end
end
