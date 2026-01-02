# frozen_string_literal: true

module Jobs
  class EpisodeSyncJob < ::Jobs::Base
    sidekiq_options queue: 'low'
    
    MAX_PAGES = 3
    
    def execute(args)
      mal_id = args[:mal_id]
      return if mal_id.blank?
      
      Rails.logger.info("[EpisodeSyncJob] Starting episode sync for MAL ID: #{mal_id}")
      
      all_episodes = []
      page = 1
      has_next = true
      
      while has_next && page <= MAX_PAGES
        response = fetch_episodes_page(mal_id, page)
        break unless response && response['data'].is_a?(Array)
        
        all_episodes.concat(response['data'])
        has_next = response.dig('pagination', 'has_next_page') || false
        page += 1
      end
      
      if all_episodes.present?
        # Bulk upsert all episodes
        AnimeDatabase::AnimeEpisodeCache.upsert_from_api(mal_id, all_episodes)
        
        # Update the anime cache timestamp
        AnimeDatabase::AnimeCache.where(mal_id: mal_id).update_all(
          episodes_synced_at: Time.current
        )
        
        Rails.logger.info("[EpisodeSyncJob] Synced #{all_episodes.length} episodes for anime #{mal_id}")
      else
        Rails.logger.warn("[EpisodeSyncJob] No episodes found for anime #{mal_id}")
      end
      
    rescue => e
      Rails.logger.error("[EpisodeSyncJob] Error syncing episodes for #{mal_id}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
    end
    
    private
    
    def fetch_episodes_page(mal_id, page)
      url = "https://api.jikan.moe/v4/anime/#{mal_id}/episodes?page=#{page}"
      
      fd = FinalDestination.new(url)
      endpoint = fd.resolve
      return nil unless endpoint
      
      response = Excon.get(
        endpoint,
        headers: { 'User-Agent' => 'Discourse Anime Plugin' },
        expects: [200, 404, 429],
        connect_timeout: 10,
        read_timeout: 15
      )
      
      if response.status == 429
        Rails.logger.warn("[EpisodeSyncJob] Rate limited on page #{page}")
        return nil
      end
      
      return nil if response.status == 404
      
      JSON.parse(response.body)
    rescue => e
      Rails.logger.error("[EpisodeSyncJob] API fetch error page #{page}: #{e.message}")
      nil
    end
  end
end
