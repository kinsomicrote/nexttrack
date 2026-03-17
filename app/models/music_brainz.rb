require 'faraday'
require 'json'
require 'ostruct'

# Client for the MusicBrainz open music encyclopedia API.
#
# Provides cultural/tag-based discovery of similar tracks by querying MusicBrainz
# for recording metadata, genre tags, and artist relationships. Used by
# RecommendationEngine as the primary source of candidate tracks before they
# are matched and scored against Spotify/ReccoBeats data.
#
# All public methods return safe defaults (empty arrays) on API failure so
# callers don't need to handle HTTP errors.
#
# Rate limiting is enforced internally — MusicBrainz allows max 1 request/second.
#
# Usage:
#   mb = MusicBrainz.new
#   candidates = mb.get_similar_tracks("Radiohead", "Creep", limit: 10)
#   tags = mb.get_track_tags("Radiohead", "Creep")
#
class MusicBrainz
  BASE_URL = "https://musicbrainz.org/ws/2/"
  USER_AGENT = "NextTrack/1.0"

  # Rate limiting: MusicBrainz allows 1 request per second
  RATE_LIMIT_DELAY = 1.1

  def initialize
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
      f.headers['User-Agent'] = USER_AGENT
      f.headers['Accept'] = 'application/json'
    end
    @last_request_time = nil
  end

  # Finds tracks similar to the given seed track using tag-based discovery.
  #
  # Strategy:
  #   1. Look up the recording on MusicBrainz to get its MBID
  #   2. Collect genre/style tags from both the recording and its artist
  #   3. Search for other recordings sharing those tags
  #   4. Find recordings by related artists (collaborators, band members)
  #   5. Deduplicate and exclude the original seed track
  #
  # @param artist [String] Artist name (e.g., "Radiohead")
  # @param track_name [String] Track title (e.g., "Creep")
  # @param limit [Integer] Maximum number of candidates to return
  # @return [Array<OpenStruct>] Candidate tracks, each with:
  #   - name [String] Track title
  #   - artist [String] Artist name
  #   - mbid [String] MusicBrainz recording ID
  #   Returns [] on API failure or if no candidates are found.
  def get_similar_tracks(artist, track_name, limit: 10)
    recording = lookup_recording(artist, track_name)
    return [] unless recording

    recording_mbid = recording['id']
    artist_mbid = recording.dig('artist-credit', 0, 'artist', 'id')

    recording_tags = get_recording_tags(recording_mbid)
    artist_tags = artist_mbid ? get_artist_tags(artist_mbid) : []

    all_tags = (recording_tags + artist_tags).uniq.first(5)

    return [] if all_tags.empty?

    candidates = []

    all_tags.first(3).each do |tag|
      break if candidates.length >= limit * 2

      tag_results = search_recordings_by_tag(tag, limit: 10)
      candidates.concat(tag_results)
    end

    if artist_mbid
      related_artists = get_related_artists(artist_mbid)
      related_artists.first(3).each do |related_artist|
        break if candidates.length >= limit * 3

        artist_recordings = get_artist_recordings(related_artist[:mbid], limit: 5)
        candidates.concat(artist_recordings)
      end
    end

    seen = Set.new
    unique_candidates = []

    candidates.each do |candidate|
      key = "#{candidate.artist&.downcase}-#{candidate.name&.downcase}"
      next if seen.include?(key)
      next if candidate.name&.downcase == track_name.downcase &&
              candidate.artist&.downcase == artist.downcase

      seen.add(key)
      unique_candidates << candidate
    end

    unique_candidates.first(limit)
  rescue StandardError => e
    puts "❌ MusicBrainz Error: #{e.message}"
    []
  end

  # Retrieves genre/style tags for a track by combining recording and artist tags.
  #
  # @param artist [String] Artist name
  # @param track_name [String] Track title
  # @param limit [Integer] Maximum number of tags to return
  # @return [Array<String>] Tag names sorted by popularity (e.g., ["rock", "alternative", "90s"]).
  #   Returns [] on API failure or if no tags are found.
  def get_track_tags(artist, track_name, limit: 10)
    recording = lookup_recording(artist, track_name)
    return [] unless recording

    recording_mbid = recording['id']
    artist_mbid = recording.dig('artist-credit', 0, 'artist', 'id')

    recording_tags = get_recording_tags(recording_mbid)
    artist_tags = artist_mbid ? get_artist_tags(artist_mbid) : []

    (recording_tags + artist_tags).uniq.first(limit)
  rescue StandardError => e
    puts "❌ MusicBrainz Tag Error: #{e.message}"
    []
  end

  private

  # Enforces MusicBrainz rate limit by sleeping if the last request was too recent.
  def rate_limit!
    if @last_request_time
      elapsed = Time.now - @last_request_time
      if elapsed < RATE_LIMIT_DELAY
        sleep(RATE_LIMIT_DELAY - elapsed)
      end
    end
    @last_request_time = Time.now
  end

  # Searches MusicBrainz for a recording matching the artist and track name.
  #
  # @return [Hash, nil] Raw MusicBrainz recording JSON (with 'id', 'artist-credit', etc.), or nil
  def lookup_recording(artist, track_name)
    rate_limit!

    query = "recording:\"#{escape_query(track_name)}\" AND artist:\"#{escape_query(artist)}\""

    response = @conn.get('recording', {
      query: query,
      fmt: 'json',
      limit: 5
    })

    return nil unless response.success?

    data = JSON.parse(response.body)
    recordings = data['recordings'] || []

    recordings.first
  end

  # Fetches tags for a specific recording, sorted by community vote count (descending).
  #
  # @param mbid [String] MusicBrainz recording ID
  # @return [Array<String>] Tag names (e.g., ["rock", "alternative"])
  def get_recording_tags(mbid)
    rate_limit!

    response = @conn.get("recording/#{mbid}", {
      inc: 'tags',
      fmt: 'json'
    })

    return [] unless response.success?

    data = JSON.parse(response.body)
    tags = data['tags'] || []

    tags.sort_by { |t| -(t['count'] || 0) }
        .map { |t| t['name'] }
  end

  # Fetches tags for a specific artist, sorted by community vote count (descending).
  #
  # @param mbid [String] MusicBrainz artist ID
  # @return [Array<String>] Tag names
  def get_artist_tags(mbid)
    rate_limit!

    response = @conn.get("artist/#{mbid}", {
      inc: 'tags',
      fmt: 'json'
    })

    return [] unless response.success?

    data = JSON.parse(response.body)
    tags = data['tags'] || []

    tags.sort_by { |t| -(t['count'] || 0) }
        .map { |t| t['name'] }
  end

  # Finds artists related to the given artist via MusicBrainz relationship data.
  # Filters for musically relevant relationships (band members, collaborators, etc.)
  # to find artists likely to produce similar-sounding music.
  #
  # @param mbid [String] MusicBrainz artist ID
  # @return [Array<Hash>] Related artists, each with :mbid, :name, :type
  def get_related_artists(mbid)
    rate_limit!

    response = @conn.get("artist/#{mbid}", {
      inc: 'artist-rels',
      fmt: 'json'
    })

    return [] unless response.success?

    data = JSON.parse(response.body)
    relations = data['relations'] || []

    # Filter for relevant relationship types
    relevant_types = ['member of band', 'collaboration', 'instrumental supporting musician',
                      'vocal supporting musician', 'conductor position', 'founder']

    related = relations.select { |r| r['type'] && relevant_types.include?(r['type'].downcase) }
                       .map do |r|
      artist = r['artist']
      next unless artist

      {
        mbid: artist['id'],
        name: artist['name'],
        type: r['type']
      }
    end.compact

    related
  end

  # Searches for recordings tagged with a specific genre/style tag.
  #
  # @param tag [String] Tag to search for (e.g., "electronic")
  # @param limit [Integer] Maximum results to return
  # @return [Array<OpenStruct>] Tracks with :name, :artist, :mbid fields
  def search_recordings_by_tag(tag, limit: 10)
    rate_limit!

    response = @conn.get('recording', {
      query: "tag:\"#{escape_query(tag)}\"",
      fmt: 'json',
      limit: limit
    })

    return [] unless response.success?

    data = JSON.parse(response.body)
    recordings = data['recordings'] || []

    recordings.map do |r|
      artist_credit = r['artist-credit']&.first
      artist_name = artist_credit&.dig('name') || artist_credit&.dig('artist', 'name')

      OpenStruct.new(
        name: r['title'],
        artist: artist_name,
        mbid: r['id']
      )
    end
  end

  # Fetches recordings by a specific artist (used to source tracks from related artists).
  #
  # @param artist_mbid [String] MusicBrainz artist ID
  # @param limit [Integer] Maximum results to return
  # @return [Array<OpenStruct>] Tracks with :name, :artist, :mbid fields
  def get_artist_recordings(artist_mbid, limit: 5)
    rate_limit!

    response = @conn.get('recording', {
      query: "arid:#{artist_mbid}",
      fmt: 'json',
      limit: limit
    })

    return [] unless response.success?

    data = JSON.parse(response.body)
    recordings = data['recordings'] || []

    recordings.map do |r|
      artist_credit = r['artist-credit']&.first
      artist_name = artist_credit&.dig('name') || artist_credit&.dig('artist', 'name')

      OpenStruct.new(
        name: r['title'],
        artist: artist_name,
        mbid: r['id']
      )
    end
  end

  # Escapes Lucene special characters for safe MusicBrainz query strings.
  def escape_query(str)
    special_chars = ['+', '-', '&&', '||', '!', '(', ')', '{', '}', '[', ']', '^', '"', '~', '*', '?', ':', '\\', '/']
    escaped = str.to_s.dup

    special_chars.each do |char|
      escaped.gsub!(char, "\\#{char}")
    end

    escaped
  end
end
