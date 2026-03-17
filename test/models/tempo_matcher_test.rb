require "test_helper"

class TempoMatcherTest < ActiveSupport::TestCase

  test "initializes with seed BPM" do
    matcher = TempoMatcher.new(120)
    assert_equal 120.0, matcher.seed_bpm
  end

  test "converts seed BPM to float" do
    matcher = TempoMatcher.new("120")
    assert_equal 120.0, matcher.seed_bpm
  end

  test "handles nil seed BPM" do
    matcher = TempoMatcher.new(nil)
    assert_nil matcher.seed_bpm
    refute matcher.valid?
  end

  test "valid? returns true for positive BPM" do
    assert TempoMatcher.new(120).valid?
    assert TempoMatcher.new(60).valid?
    assert TempoMatcher.new(180).valid?
  end

  test "valid? returns false for zero or negative BPM" do
    refute TempoMatcher.new(0).valid?
    refute TempoMatcher.new(-120).valid?
  end

  test "exact tempo match scores 1.0" do
    matcher = TempoMatcher.new(120)
    assert_equal 1.0, matcher.similarity_score(120)
  end

  test "near-perfect match (within 5%) scores 1.0" do
    matcher = TempoMatcher.new(120)

    assert_equal 1.0, matcher.similarity_score(118)
    assert_equal 1.0, matcher.similarity_score(122)
    assert_equal 1.0, matcher.similarity_score(114)
    assert_equal 1.0, matcher.similarity_score(126)
  end

  test "same tempo with 10% tolerance scores 0.9" do
    matcher = TempoMatcher.new(120)

    assert_equal 0.9, matcher.similarity_score(108)
    assert_equal 0.9, matcher.similarity_score(132)
    assert_equal 0.9, matcher.similarity_score(110)
    assert_equal 0.9, matcher.similarity_score(130)
  end

  test "tempo just outside 10% tolerance scores lower" do
    matcher = TempoMatcher.new(120)

    assert matcher.similarity_score(105.6) < 0.9

    assert matcher.similarity_score(134.4) < 0.9
  end

  test "exact double tempo scores 0.85" do
    matcher = TempoMatcher.new(120)
    assert_equal 0.85, matcher.similarity_score(240)
  end

  test "near-perfect double tempo (1.95-2.05) scores 0.85" do
    matcher = TempoMatcher.new(120)

    assert_equal 0.85, matcher.similarity_score(234)
    assert_equal 0.85, matcher.similarity_score(246)
  end

  test "double tempo with tolerance (1.9-2.1) scores 0.7" do
    matcher = TempoMatcher.new(120)

    assert_equal 0.7, matcher.similarity_score(228)
    assert_equal 0.7, matcher.similarity_score(252)
  end

  test "exact half tempo scores 0.85" do
    matcher = TempoMatcher.new(120)
    assert_equal 0.85, matcher.similarity_score(60)
  end

  test "near-perfect half tempo (0.48-0.52) scores 0.85" do
    matcher = TempoMatcher.new(120)

    assert_equal 0.85, matcher.similarity_score(57.6)
    assert_equal 0.85, matcher.similarity_score(62.4)
  end

  test "half tempo with tolerance (0.45-0.55) scores 0.7" do
    matcher = TempoMatcher.new(120)

    assert_equal 0.7, matcher.similarity_score(54)
    assert_equal 0.7, matcher.similarity_score(66)
  end

  test "extended range (0.8-1.2) scores 0.5" do
    matcher = TempoMatcher.new(120)

    assert_equal 0.5, matcher.similarity_score(100)
    assert_equal 0.5, matcher.similarity_score(140)
  end

  test "distant tempo (outside all ranges) scores 0.2" do
    matcher = TempoMatcher.new(120)

    assert_equal 0.2, matcher.similarity_score(80)
    assert_equal 0.2, matcher.similarity_score(180)
    assert_equal 0.2, matcher.similarity_score(300)
  end

  test "nil candidate BPM returns default score 0.5" do
    matcher = TempoMatcher.new(120)
    assert_equal 0.5, matcher.similarity_score(nil)
  end

  test "nil seed BPM returns default score 0.5" do
    matcher = TempoMatcher.new(nil)
    assert_equal 0.5, matcher.similarity_score(120)
  end

  test "zero candidate BPM returns default score 0.5" do
    matcher = TempoMatcher.new(120)
    assert_equal 0.5, matcher.similarity_score(0)
  end

  test "zero seed BPM returns default score 0.5" do
    matcher = TempoMatcher.new(0)
    assert_equal 0.5, matcher.similarity_score(120)
  end

  test "describe_relationship for exact match" do
    matcher = TempoMatcher.new(120)
    assert_equal "Near-perfect match", matcher.describe_relationship(120)
  end

  test "describe_relationship for same tempo range" do
    matcher = TempoMatcher.new(120)
    assert_equal "Same tempo (±10%)", matcher.describe_relationship(108)
  end

  test "describe_relationship for double time" do
    matcher = TempoMatcher.new(120)
    assert_equal "Double time", matcher.describe_relationship(240)
  end

  test "describe_relationship for half time" do
    matcher = TempoMatcher.new(120)
    assert_equal "Half time", matcher.describe_relationship(60)
  end

  test "describe_relationship for extended range" do
    matcher = TempoMatcher.new(120)
    assert_equal "Mixable with pitch adjustment", matcher.describe_relationship(140)
  end

  test "describe_relationship for incompatible tempo" do
    matcher = TempoMatcher.new(120)
    assert_equal "Incompatible tempo", matcher.describe_relationship(80)
  end

  test "describe_relationship for missing data" do
    matcher = TempoMatcher.new(120)
    assert_equal "Unknown (missing tempo data)", matcher.describe_relationship(nil)

    matcher_nil = TempoMatcher.new(nil)
    assert_equal "Unknown (missing tempo data)", matcher_nil.describe_relationship(120)
  end

end
