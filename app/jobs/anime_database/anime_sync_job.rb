# frozen_string_literal: true

module Jobs
  class AnimeSyncJob < ::Jobs::Base
    sidekiq_options queue: 'low'
    
    MAX_IMAGE_SIZE = 5.megabytes
    
    def execute(args)
      mal_id = args[:mal_id]
      return if mal_id.blank?
      
      Rails.logger.info("[AnimeSyncJob] Starting sync for MAL ID: #{mal_id}")
      
      # Fetch from Jikan API
      response = fetch_anime_data(mal_id)
      return unless response && response['data']
      
      data = response['data']
      image_url = data.dig('images', 'jpg', 'large_image_url')
      
      # Upsert into local cache
      AnimeDatabase::AnimeCache.upsert({
        mal_id: mal_id,
        title: data['title'],
        title_english: data['title_english'],
        title_japanese: data['title_japanese'],
        synopsis: data['synopsis'],
        image_url: image_url,
        banner_url: data.dig('images', 'jpg', 'image_url'),
        score: data['score'],
        scored_by: data['scored_by'],
        rank: data['rank'],
        popularity: data['popularity'],
        members: data['members'],
        episodes_total: data['episodes'],
        airing_status: map_status(data['status']),
        aired_from: parse_date(data.dig('aired', 'from')),
        aired_to: parse_date(data.dig('aired', 'to')),
        season: data['season'],
        year: data['year'],
        source: data['source'],
        rating: data['rating'],
        duration_minutes: parse_duration(data['duration']),
        genres: extract_names(data['genres']),
        studios: extract_names(data['studios']),
        producers: extract_names(data['producers']),
        themes: extract_names(data['themes']),
        demographics: extract_names(data['demographics']),
        raw_jikan: data,
        last_api_sync_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      }, unique_by: :mal_id)
      
      Rails.logger.info("[AnimeSyncJob] Successfully synced anime #{mal_id}: #{data['title']}")
      
      # Download and upload image to Discourse
      if image_url.present?
        download_and_upload_image(mal_id, image_url)
      end
      
      # Queue episode sync if anime is airing
      if map_status(data['status']) == 'airing'
        Jobs.enqueue(:episode_sync_job, mal_id: mal_id)
      end
      
    rescue => e
      Rails.logger.error("[AnimeSyncJob] Error syncing anime #{mal_id}: #{e.class} - #{e.message}")
      Rails.logger.error(e.backtrace.first(5).join("\n"))
    end
    
    private
    
    def download_and_upload_image(mal_id, image_url)
      anime_cache = AnimeDatabase::AnimeCache.find_by(mal_id: mal_id)
      return unless anime_cache
      
      # Skip if already has a local image
      if anime_cache.local_image_url.present?
        Rails.logger.debug("[AnimeSyncJob] Anime #{mal_id} already has local image")
        return
      end
      
      begin
        # Download image
        tempfile = FileHelper.download(
          image_url,
          max_file_size: MAX_IMAGE_SIZE,
          tmp_file_name: "anime_#{mal_id}",
          follow_redirect: true
        )
        
        sleep(0.5) # Be polite to Jikan/MyAnimeList CDNs
        
        return unless tempfile
        
        # Determine filename
        filename = "anime_cover_#{mal_id}.jpg"
        
        # Create upload using Discourse's UploadCreator
        upload = UploadCreator.new(
          tempfile,
          filename,
          type: "composer"
        ).create_for(Discourse.system_user.id)
        
        if upload.persisted?
          anime_cache.update(
            local_image_upload_id: upload.id,
            local_image_url: upload.url
          )
          Rails.logger.info("[AnimeSyncJob] Uploaded image for anime #{mal_id}: #{upload.url}")
        else
          Rails.logger.warn("[AnimeSyncJob] Failed to upload image for anime #{mal_id}: #{upload.errors.full_messages.join(', ')}")
        end
        
      rescue => e
        Rails.logger.error("[AnimeSyncJob] Error downloading/uploading image for #{mal_id}: #{e.message}")
      ensure
        tempfile&.close!
      end
    end

    def fetch_anime_data(mal_id)
      url = "https://api.jikan.moe/v4/anime/#{mal_id}/full"
      
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
        Rails.logger.warn("[AnimeSyncJob] Rate limited, will retry later")
        return nil
      end
      
      return nil if response.status == 404
      
      JSON.parse(response.body)
    rescue => e
      Rails.logger.error("[AnimeSyncJob] API fetch error: #{e.message}")
      nil
    end
    
    def map_status(status)
      case status
      when 'Currently Airing' then 'airing'
      when 'Finished Airing' then 'finished'
      when 'Not yet aired' then 'upcoming'
      else 'unknown'
      end
    end
    
    def parse_date(date_str)
      return nil unless date_str.present?
      Date.parse(date_str)
    rescue
      nil
    end
    
    def parse_duration(duration_str)
      return nil unless duration_str.present?
      match = duration_str.match(/(\d+)\s*min/)
      match ? match[1].to_i : nil
    end
    
    def extract_names(items)
      return [] unless items.is_a?(Array)
      items.map { |item| item['name'] }.compact
    end
  end
end
