module Api
  module V1
    class TracksController < ApplicationController
      skip_before_action :verify_authenticity_token

      def search
        query = params[:q].to_s.strip

        if query.length < 2
          render json: { results: [] }, status: :ok
          return
        end

        begin
          spotify = Spotify.new
          tracks = RSpotify::Track.search(query, limit: 7)

          results = tracks.map do |track|
            {
              id: track.id,
              name: track.name,
              artist: track.artists.first&.name || "Unknown Artist",
              album: track.album&.name || "Unknown Album",
              year: track.album&.release_date&.slice(0, 4) || "",
              image_url: track.album&.images&.find { |img| img["width"] == 64 }&.dig("url") ||
                         track.album&.images&.last&.dig("url") ||
                         ""
            }
          end

          render json: { results: results }, status: :ok

        rescue StandardError => e
          puts "Track Search Error: #{e.message}"
          render json: {
            error: "Search failed",
            details: e.message
          }, status: :bad_request
        end
      end
    end
  end
end
