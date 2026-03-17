require 'ostruct'
require 'parallel'
require 'amatch'

# Orchestrates the music recommendation process.
#
# This class coordinates the retrieval of candidate tracks from external services,
# scores them using audio feature analysis and music theory rules, and returns
# ranked recommendations. It delegates specific responsibilities to specialized
# classes:
#
#   - KeyCompatibility: Circle of Fifths harmonic compatibility
#   - TempoMatcher: BPM matching for DJ-style transitions
#   - AudioFeatures: Track audio characteristics value object
#   - SimilarityScorer: Multi-dimensional similarity scoring
#   - RecommendationResponse: API response formatting
#
# Usage:
#   engine = RecommendationEngine.new("spotify_track_id")
#   result = engine.process
#   # => { seed_track: {...}, recommendations: [...], metadata: {...} }
#
class RecommendationEngine
  MAX_SCORE = 1.0

  attr_reader :seed_track, :seed_features, :use_audio_features

  # @param seed_track_id [String] Spotify track ID for the seed track
  # @param user_targets [Hash] Optional target values for energy, valence, danceability
  # @param use_audio_features [Boolean] Whether to use audio feature analysis
  # @param limit [Integer] Maximum number of recommendations to return
  # @param spotify [Spotify] Spotify service instance (injected dependency)
  # @param musicbrainz [MusicBrainz] MusicBrainz service instance (injected dependency)
  # @param recco_beats [ReccoBeats] ReccoBeats service instance (injected dependency)
  def initialize(seed_track_id,
                 user_targets: {},
                 use_audio_features: true,
                 limit: 5,
                 spotify: nil,
                 musicbrainz: nil,
                 recco_beats: nil)
    @spotify = spotify || Spotify.new
    @musicbrainz = musicbrainz || MusicBrainz.new
    @user_targets = user_targets.transform_keys(&:to_s)
    @use_audio_features = use_audio_features
    @limit = limit

    @seed_track = @spotify.get_track(seed_track_id)
    @seed_tags = @musicbrainz.get_track_tags(primary_artist_name, @seed_track.name)

    if @use_audio_features
      @recco = recco_beats || ReccoBeats.new
      raw_features = @recco.get_audio_features(seed_track_id)
      @seed_features = AudioFeatures.from_recco_beats(raw_features)
      raise "Could not fetch seed features!" unless @seed_features&.valid?
    else
      @recco = nil
      @seed_features = nil
    end

    @scorer = SimilarityScorer.new(@seed_features, user_targets: @user_targets)
  end

  # Processes the recommendation request and returns ranked results.
  #
  # @return [Hash] Recommendation response with seed_track, recommendations, and metadata
  def process
    start_time = Time.now
    log_analysis_start

    raw_candidates = fetch_candidates
    log_candidates_found(raw_candidates.length, start_time)

    return empty_response if raw_candidates.empty?

    spotify_matches = parallel_spotify_search(raw_candidates)
    valid_matches = spotify_matches.select { |m| m[:spotify_track] }
    log_spotify_matches(valid_matches.length, raw_candidates.length)

    return empty_response if valid_matches.empty?

    if @use_audio_features
      valid_matches = parallel_fetch_features(valid_matches)
    end

    scored_candidates = score_candidates(valid_matches)

    ranked = scored_candidates.sort_by { |c| -c[:score] }.first(@limit)

    log_completion(ranked.first, start_time)

    build_response(ranked)
  end

  private

  # Retrieves raw candidate tracks from MusicBrainz based on the seed track's
  # artist and name. Returns up to 20 candidates as OpenStruct objects.
  #
  # @return [Array<OpenStruct>] Candidates with :name, :artist, :mbid fields
  def fetch_candidates
    @musicbrainz.get_similar_tracks(
      primary_artist_name,
      @seed_track.name,
      limit: 20
    )
  end

  # Searches Spotify for each candidate in parallel (5 threads).
  # Falls back to sequential search if threading fails (e.g., deadlock, resource exhaustion).
  #
  # @param candidates [Array<OpenStruct>] MusicBrainz candidate tracks
  # @return [Array<Hash>] Each hash has :candidate and :spotify_track (may be nil if not found)
  def parallel_spotify_search(candidates)
    Parallel.map(candidates, in_threads: 5) do |candidate|
      spotify_track = find_best_spotify_match(candidate.name, candidate.artist)
      { candidate: candidate, spotify_track: spotify_track }
    end
  rescue => e
    puts "Parallel search failed, falling back to sequential: #{e.message}"
    sequential_spotify_search(candidates)
  end

  # Sequential fallback for parallel_spotify_search.
  def sequential_spotify_search(candidates)
    candidates.map do |candidate|
      spotify_track = find_best_spotify_match(candidate.name, candidate.artist)
      { candidate: candidate, spotify_track: spotify_track }
    end
  end

  # Fetches audio features for all matched tracks in parallel (5 threads).
  # Falls back to sequential fetching if threading fails.
  # Filters out matches where features could not be retrieved.
  #
  # @param matches [Array<Hash>] Spotify-matched candidates (each with :spotify_track)
  # @return [Array<Hash>] Matches enriched with :features (AudioFeatures), only those with valid features
  def parallel_fetch_features(matches)
    track_ids = matches.map { |m| m[:spotify_track].id }
    features_map = {}

    Parallel.each(track_ids, in_threads: 5) do |track_id|
      raw = @recco.get_audio_features(track_id)
      features_map[track_id] = AudioFeatures.from_recco_beats(raw)
    end

    matches.map do |match|
      features = features_map[match[:spotify_track].id]
      match.merge(features: features)
    end.select { |m| m[:features] }
  rescue => e
    puts "Parallel feature fetch failed: #{e.message}"
    sequential_fetch_features(matches)
  end

  # Sequential fallback for parallel_fetch_features.
  def sequential_fetch_features(matches)
    matches.map do |match|
      raw = @recco.get_audio_features(match[:spotify_track].id)
      match.merge(features: AudioFeatures.from_recco_beats(raw))
    end.select { |m| m[:features] }
  end

  # Finds the best Spotify track match for a candidate's name and artist.
  #
  # Uses a two-pass search strategy:
  #   1. Structured query: "track:<name> artist:<artist>"
  #   2. Fallback freetext: "<name> <artist>" (if structured returns no results)
  #
  # Results are ranked by Jaro-Winkler string similarity. If the best match
  # scores >= 0.4 it is returned; otherwise falls back to the first result
  # (since a low-confidence match from Spotify is often still relevant).
  #
  # @param track_name [String] Track title to search for
  # @param artist_name [String] Artist name to search for
  # @return [RSpotify::Track, nil] Best matching Spotify track, or nil if nothing found
  def find_best_spotify_match(track_name, artist_name)
    search_query = "track:#{track_name} artist:#{artist_name}"
    results = RSpotify::Track.search(search_query, limit: 5)

    if results.empty?
      results = RSpotify::Track.search("#{track_name} #{artist_name}", limit: 5)
    end

    return nil if results.empty?

    best_match = score_spotify_results(results, track_name, artist_name)
    best_match[:score] >= 0.4 ? best_match[:track] : results.first
  end

  # Ranks Spotify search results by combined track name + artist name similarity.
  # Weighted 60% track name, 40% artist name — track title is more distinctive.
  #
  # @param results [Array<RSpotify::Track>] Spotify search results
  # @param track_name [String] Expected track name
  # @param artist_name [String] Expected artist name
  # @return [Hash] { track: RSpotify::Track, score: Float } for the best match
  def score_spotify_results(results, track_name, artist_name)
    scored = results.map do |track|
      track_sim = string_similarity(track_name, track.name)
      artist_sim = track.artists.map { |a| string_similarity(artist_name, a.name) }.max || 0
      combined = (track_sim * 0.6) + (artist_sim * 0.4)
      { track: track, score: combined }
    end

    scored.max_by { |r| r[:score] } || { track: nil, score: 0 }
  end

  # Computes string similarity using Jaro-Winkler distance (0.0 to 1.0).
  # Falls back to simple containment check if the Amatch gem raises an error.
  #
  # @return [Float] Similarity score between 0.0 (no match) and 1.0 (exact match)
  def string_similarity(str1, str2)
    return 1.0 if str1 == str2
    return 0.0 if str1.nil? || str2.nil? || str1.empty? || str2.empty?

    matcher = Amatch::JaroWinkler.new(str1.to_s.downcase)
    matcher.match(str2.to_s.downcase)
  rescue => e
    simple_containment_score(str1, str2)
  end

  # Fallback similarity: returns 0.8 if either string contains the other, 0.0 otherwise.
  def simple_containment_score(str1, str2)
    s1, s2 = str1.to_s.downcase, str2.to_s.downcase
    (s1.include?(s2) || s2.include?(s1)) ? 0.8 : 0.0
  end

  # Scores each candidate using the SimilarityScorer and merges results into the match hash.
  # Adds :score, :confidence, :reasons, and :breakdown to each match.
  #
  # @param matches [Array<Hash>] Candidates with :features (AudioFeatures)
  # @return [Array<Hash>] Candidates enriched with scoring data
  def score_candidates(matches)
    matches.map do |match|
      score_result = @scorer.score(match[:features])

      match.merge(
        score: score_result[:similarity],
        confidence: score_result[:confidence],
        reasons: score_result[:reasons],
        breakdown: score_result[:breakdown]
      )
    end
  end

  # Builds an empty response (used when no candidates or matches are found).
  def empty_response
    RecommendationResponse.new(
      seed_track: @seed_track,
      seed_features: @seed_features,
      recommendations: [],
      audio_features_enabled: @use_audio_features
    ).to_h
  end

  # Builds the final response hash from ranked candidates via RecommendationResponse.
  def build_response(ranked)
    RecommendationResponse.new(
      seed_track: @seed_track,
      seed_features: @seed_features,
      recommendations: ranked,
      audio_features_enabled: @use_audio_features
    ).to_h
  end

  # Extracts the first artist's name from the seed track.
  def primary_artist_name
    @seed_track.artists.first.name
  end

  def log_analysis_start
    puts "Analyzing Seed: #{@seed_track.name}"
    puts "Audio Features: #{@use_audio_features ? 'ENABLED' : 'DISABLED'}"

    if @use_audio_features && @seed_features
      puts "Seed Tempo: #{@seed_features.tempo} BPM"
      puts "Seed Key: #{@seed_features.key_compatibility.name}"
    end
    puts "Seed Tags: #{@seed_tags.inspect}"
  end

  def log_candidates_found(count, start_time)
    elapsed = (Time.now - start_time).round(2)
    puts "MusicBrainz returned #{count} candidates (#{elapsed}s)"
  end

  def log_spotify_matches(found, total)
    puts "Spotify matching complete: #{found}/#{total} found"
  end

  def log_completion(top_match, start_time)
    total_time = (Time.now - start_time).round(2)

    if top_match
      confidence = (top_match[:confidence] * 100).round(1)
    end
  end
end
