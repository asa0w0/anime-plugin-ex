# frozen_string_literal: true

module Jobs
  class AnimeDatabaseWatchlistSync < ::Jobs::Base
    sidekiq_options queue: 'low'

    def execute(args)
      anime_ids = args[:anime_ids] || []
      return if anime_ids.empty?

      anime_ids.each do |anime_id|
        begin
          # Fetch from Jikan API
          url = "https://api.jikan.moe/v4/anime/#{anime_id}"
          uri = URI(url)
          
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
            http.get(uri.request_uri)
          end

          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            if data && data["data"]
              episodes = data["data"]["episodes"].to_i
              if episodes > 0
                # Update all watchlist entries for this anime
                DB.exec("UPDATE anime_watchlists SET total_episodes = ? WHERE anime_id = ? AND (total_episodes IS NULL OR total_episodes = 0)", 
                       episodes, anime_id.to_s)
                
                Rails.logger.info("[WatchlistSync] Updated anime #{anime_id} with #{episodes} episodes")
              end
            end
          end

          # Rate limit - Jikan allows ~3 requests per second
          sleep(0.4)
        rescue => e
          Rails.logger.warn("[WatchlistSync] Failed to fetch anime #{anime_id}: #{e.message}")
        end
      end
    end
  end
end
