# frozen_string_literal: true

namespace :anime_database do
  desc "Clear all cached anime and episode data"
  task clear_cache: :environment do
    puts "Clearing anime cache..."
    count = AnimeDatabase::AnimeCache.destroy_all.count
    puts "Cleared #{count} anime cache records."
    
    if defined?(AnimeDatabase::AnimeEpisodeCache)
      ep_count = AnimeDatabase::AnimeEpisodeCache.destroy_all.count
      puts "Cleared #{ep_count} episode cache records."
    end
    
    puts "Done."
  end

  desc "Mark all cached anime as stale to trigger background refresh"
  task refresh_cache: :environment do
    puts "Marking all anime as stale..."
    count = AnimeDatabase::AnimeCache.update_all(last_api_sync_at: 1.year.ago)
    puts "Marked #{count} records as stale. They will be refreshed on next access."
  end

  desc "Manually trigger background sync for all cached airing anime"
  task sync_airing: :environment do
    puts "Queueing sync for all airing anime..."
    synced = 0
    AnimeDatabase::AnimeCache.where(airing_status: 'airing').find_each do |anime|
      Jobs.enqueue(:anime_sync_job, mal_id: anime.mal_id)
      synced += 1
      print "." if synced % 10 == 0
    end
    puts "\nQueued #{synced} airing anime for sync."
  end

  desc "Sync a specific anime by MAL ID"
  task :sync_anime, [:mal_id] => :environment do |t, args|
    mal_id = args[:mal_id]
    if mal_id.blank?
      puts "Error: Please provide a MAL ID. Usage: rake anime_database:sync_anime[12345]"
      exit 1
    end
    
    puts "Queueing sync for anime #{mal_id}..."
    Jobs.enqueue(:anime_sync_job, mal_id: mal_id)
    puts "Done."
  end
end
