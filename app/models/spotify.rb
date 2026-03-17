# Thin wrapper around the RSpotify gem for Spotify Web API access.
#
# Handles authentication via client credentials (stored in Rails credentials)
# and provides convenience methods for track lookup, audio features, and
# recommendations. Authentication happens automatically on initialization.
#
# All return types are RSpotify objects (RSpotify::Track, RSpotify::AudioFeatures, etc.)
# which provide attribute access via methods (e.g., track.name, track.artists).
#
# Usage:
#   spotify = Spotify.new
#   track = spotify.get_track("6rqhFgbbKwnb9MLmUQDhG6")
#   track.name     # => "Bohemian Rhapsody"
#   track.artists  # => [RSpotify::Artist, ...]
#
class Spotify
  # Reads Spotify API credentials from Rails encrypted credentials and authenticates.
  def initialize
    @client_id = Rails.application.credentials.spotify[:client_id]
    @client_secret = Rails.application.credentials.spotify[:client_secret]
    authenticate!
  end

  # Authenticates with Spotify using client credentials flow.
  # Called automatically by initialize; can be called again to re-authenticate.
  def authenticate!
    RSpotify.authenticate(@client_id, @client_secret)
  end

  # Looks up a single track by its Spotify ID.
  #
  # @param track_id [String] Spotify track ID (e.g., "6rqhFgbbKwnb9MLmUQDhG6")
  # @return [RSpotify::Track] Track object with .name, .artists, .id, .external_urls, etc.
  def get_track(track_id)
    RSpotify::Track.find(track_id)
  end
end
