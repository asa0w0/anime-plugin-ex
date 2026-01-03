# frozen_string_literal: true

module Jobs
  class WatchlistSyncJob < ::Jobs::Base
    sidekiq_options queue: 'low'

    def execute(args)
      anime_ids = args[:anime_ids] || []
      return if anime_ids.empty?

      anime_ids.each do |anime_id|
        begin
          # Try AniList first (better rate limits, faster)
          anilist_data = AnilistService.fetch_by_mal_id(anime_id)
          episodes = anilist_data&.dig("episodes").to_i

          # Fallback to Jikan if AniList failed or has no episode count
          if episodes <= 0
            url = "https://api.jikan.moe/v4/anime/#{anime_id}"
            uri = URI(url)
            sleep(1.0) # Rate limit for Jikan fallback
            
            response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
              http.get(uri.request_uri, { "User-Agent" => "Discourse Anime Plugin" })
            end

            if response.is_a?(Net::HTTPSuccess)
              data = JSON.parse(response.body)
              episodes = data.dig("data", "episodes").to_i
            end
          end

          if episodes > 0
            # Update all watchlist entries for this anime
            DB.exec("UPDATE anime_watchlists SET total_episodes = ? WHERE anime_id = ? AND (total_episodes IS NULL OR total_episodes = 0)", 
                   episodes, anime_id.to_s)
            
            # Also trigger a full sync to populate the local cache for the show page
            Jobs.enqueue(:anime_sync_job, mal_id: anime_id.to_i)
            
            Rails.logger.info("[WatchlistSync] Updated anime #{anime_id} with #{episodes} episodes using #{anilist_data ? 'AniList' : 'Jikan'}")
          end
        rescue => e
          Rails.logger.warn("[WatchlistSync] Failed to fetch anime #{anime_id}: #{e.message}")
        end
      end
    end
  end
end
