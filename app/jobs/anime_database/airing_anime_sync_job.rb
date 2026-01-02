# frozen_string_literal: true

module Jobs
  class AiringAnimeSyncJob < ::Jobs::Scheduled
    every 1.day
    
    def execute(args)
      Rails.logger.info("[AiringAnimeSyncJob] Starting daily sync of airing anime...")
      
      synced_count = 0
      
      # Sync all anime marked as "airing" in our cache
      AnimeDatabase::AnimeCache.airing.find_each do |anime|
        Jobs.enqueue(:anime_sync_job, mal_id: anime.mal_id)
        synced_count += 1
        
        # Small delay to avoid rate limiting
        sleep 0.1
      end
      
      # Also sync anime that users are actively watching
      watching_anime_ids = DB.query_single(<<~SQL)
        SELECT DISTINCT anime_id FROM anime_watchlists WHERE status = 'watching'
      SQL
      
      watching_anime_ids.each do |anime_id|
        # Skip if already queued from airing list
        next if AnimeDatabase::AnimeCache.airing.exists?(mal_id: anime_id)
        
        Jobs.enqueue(:anime_sync_job, mal_id: anime_id)
        synced_count += 1
        sleep 0.1
      end
      
      Rails.logger.info("[AiringAnimeSyncJob] Queued #{synced_count} anime for sync")
    end
  end
end
