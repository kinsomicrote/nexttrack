require 'faraday'
require 'json'
require 'ostruct'

# Client for the ReccoBeats API — provides audio feature analysis and track recommendations.
#
# ReccoBeats is used for:
# Fetching audio features (tempo, key, energy, etc.) for similarity scoring

class ReccoBeats
  BASE_URL = "https://api.reccobeats.com/v1"

  def initialize
    @conn = Faraday.new(url: BASE_URL) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
    end
  end

  # Fetches audio analysis features for a single track.
  #
  # @param track_id [String] Spotify track ID (ReccoBeats uses Spotify IDs as identifiers)
  # @return [OpenStruct, nil] Audio features with fields:
  #   - id [String] Track ID
  #   - tempo [Float] Tempo in BPM
  #   - key [Integer] Pitch class (0-11, where C=0)
  #   - mode [Integer] Mode (1=major, 0=minor)
  #   - energy [Float] Energy level (0.0-1.0)
  #   - valence [Float] Musical positiveness (0.0-1.0)
  #   - danceability [Float] Danceability score (0.0-1.0)
  #   Returns nil on API failure or if no data is available.
  def get_audio_features(track_id)
    response = @conn.get("audio-features", { ids: [track_id] })
    return nil unless response.success?

    data = JSON.parse(response.body)
    parse_features(data["content"]&.first)
  rescue Faraday::Error => e
    puts "❌ ReccoBeats Error: #{e.message}"
    nil
  end

  private

  # Parses raw API response hash into an OpenStruct with typed audio feature fields.
  #
  # @param data [Hash, nil] Single item from the API "content" array
  # @return [OpenStruct, nil] Parsed features, or nil if data is blank
  def parse_features(data)
    return nil unless data
    OpenStruct.new(
      id: data["id"],
      tempo: data["tempo"],
      key: data["key"],
      mode: data["mode"],
      energy: data["energy"],
      valence: data["valence"],
      danceability: data["danceability"]
    )
  end
end
