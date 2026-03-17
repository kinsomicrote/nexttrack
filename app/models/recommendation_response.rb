# Formats recommendation results for API response.
#
# Encapsulates the presentation logic for transforming internal recommendation
# data into the JSON structure expected by API consumers. Separates response
# formatting concerns from the recommendation algorithm.
#
# Usage:
#   response = RecommendationResponse.new(
#     seed_track: spotify_track,
#     seed_features: audio_features,
#     recommendations: ranked_matches,
#     audio_features_enabled: true
#   )
#
#   response.to_h  # => { seed_track: {...}, recommendations: [...], metadata: {...} }
#
class RecommendationResponse
  # @param seed_track [Object] The Spotify track object for the seed
  # @param seed_features [AudioFeatures, nil] Audio features of the seed track
  # @param recommendations [Array<Hash>] Ranked recommendation matches
  # @param audio_features_enabled [Boolean] Whether audio features were used
  def initialize(seed_track:, seed_features:, recommendations:, audio_features_enabled:)
    @seed_track = seed_track
    @seed_features = seed_features
    @recommendations = recommendations || []
    @audio_features_enabled = audio_features_enabled
  end

  # Converts the recommendation response to a hash suitable for JSON serialization.
  #
  # @return [Hash] Complete API response structure
  def to_h
    {
      seed_track: format_seed_track,
      recommendations: format_recommendations,
      metadata: metadata
    }
  end

  # Checks if any recommendations were found.
  #
  # @return [Boolean] true if recommendations exist
  def any?
    @recommendations.any?
  end

  # Returns the number of recommendations.
  #
  # @return [Integer] Count of recommendations
  def count
    @recommendations.length
  end

  private

  # Formats the seed track information.
  def format_seed_track
    return nil unless @seed_track

    {
      name: @seed_track.name,
      artist: primary_artist_name(@seed_track),
      spotify_id: @seed_track.id,
      features: format_seed_features
    }
  end

  # Formats the seed track's audio features.
  def format_seed_features
    return nil unless @seed_features

    {
      tempo: @seed_features.tempo&.round(1),
      key: @seed_features.key_compatibility.name,
      energy: @seed_features.energy&.round(2),
      valence: @seed_features.valence&.round(2)
    }
  end

  # Formats all recommendations into an array.
  def format_recommendations
    @recommendations.map.with_index do |match, index|
      format_single_recommendation(match, index + 1)
    end
  end

  # Formats a single recommendation match.
  def format_single_recommendation(match, rank)
    spotify_track = match[:spotify_track]

    {
      rank: rank,
      track: {
        name: spotify_track.name,
        artist: primary_artist_name(spotify_track),
        spotify_id: spotify_track.id,
        spotify_url: spotify_url(spotify_track)
      },
      confidence: format_confidence(match[:confidence]),
      reasons: match[:reasons] || [],
      scores: match[:breakdown] || {}
    }
  end

  # Extracts the primary artist name from a track.
  def primary_artist_name(track)
    return "Unknown Artist" unless track.respond_to?(:artists)

    artists = track.artists
    return "Unknown Artist" if artists.nil? || artists.empty?

    first_artist = artists.first
    first_artist.respond_to?(:name) ? first_artist.name : first_artist.to_s
  end

  # Extracts the Spotify URL from a track.
  def spotify_url(track)
    return nil unless track.respond_to?(:external_urls)

    urls = track.external_urls
    urls.is_a?(Hash) ? urls["spotify"] : nil
  end

  # Formats confidence as a percentage.
  def format_confidence(confidence)
    return 0.0 unless confidence

    (confidence * 100).round(1)
  end

  # Builds the response metadata.
  def metadata
    {
      audio_features_enabled: @audio_features_enabled,
      candidates_found: @recommendations.length,
      processing_note: processing_note
    }
  end

  # Returns a human-readable description of the processing method.
  def processing_note
    if @audio_features_enabled
      "Ranked by cosine similarity with harmonic compatibility"
    else
      "Ranked by cultural similarity only (audio features disabled)"
    end
  end
end
