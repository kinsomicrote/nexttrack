module Api
  module V1
    class RecommendationsController < ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        track_id = params[:track_id]
        user_targets = params[:targets] || {}
        use_audio_features = params.fetch(:use_audio_features, true)
        limit = params.fetch(:limit, 5).to_i.clamp(1, 10)

        # Convert string "false" to boolean false (params may come as strings)
        use_audio_features = ActiveModel::Type::Boolean.new.cast(use_audio_features)

        if track_id.blank?
          render json: { error: "track_id is required" }, status: :unprocessable_entity
          return
        end

        begin
          engine = RecommendationEngine.new(
            track_id,
            user_targets: user_targets,
            use_audio_features: use_audio_features,
            limit: limit
          )
          result = engine.process

          render json: {
            status: "success",
            seed_track: result[:seed_track],
            audio_features_enabled: use_audio_features,
            recommendations: result[:recommendations],
            metadata: result[:metadata]
          }, status: :ok

        rescue StandardError => e
          puts "Recommendation Error: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          render json: {
            error: "Recommendation Failed",
            details: e.message
          }, status: :bad_request
        end
      end
    end
  end
end
