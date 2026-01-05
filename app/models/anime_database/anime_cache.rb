# frozen_string_literal: true

module AnimeDatabase
  class AnimeCache < ActiveRecord::Base
    self.table_name = 'anime_cache'
    
    # Stale thresholds
    FINISHED_STALE_THRESHOLD = 7.days
    AIRING_STALE_THRESHOLD = 6.hours
    UPCOMING_STALE_THRESHOLD = 24.hours
    
    # Scopes
    scope :airing, -> { where(airing_status: 'airing') }
    scope :finished, -> { where(airing_status: 'finished') }
    scope :upcoming, -> { where(airing_status: 'upcoming') }
    scope :by_season, ->(year, season) { where(year: year, season: season) }
    scope :top_rated, -> { order(score: :desc) }
    scope :popular, -> { order(popularity: :asc) }
    
    scope :stale, -> {
      where(
        "(airing_status = 'airing' AND last_api_sync_at < ?) OR " \
        "(airing_status = 'finished' AND last_api_sync_at < ?) OR " \
        "(airing_status = 'upcoming' AND last_api_sync_at < ?) OR " \
        "last_api_sync_at IS NULL",
        AIRING_STALE_THRESHOLD.ago,
        FINISHED_STALE_THRESHOLD.ago,
        UPCOMING_STALE_THRESHOLD.ago
      )
    }
    
    scope :needs_episode_sync, -> {
      airing.where('episodes_synced_at IS NULL OR episodes_synced_at < ?', AIRING_STALE_THRESHOLD.ago)
    }
    
    # Check if this record needs a refresh
    def stale?
      return true if last_api_sync_at.nil?
      
      threshold = case airing_status
                  when 'airing' then AIRING_STALE_THRESHOLD
                  when 'upcoming' then UPCOMING_STALE_THRESHOLD
                  else FINISHED_STALE_THRESHOLD
                  end
      
      last_api_sync_at < threshold.ago
    end
    
    def episodes_stale?
      return true if episodes_synced_at.nil?
      return false if airing_status == 'finished' && episodes_synced_at > 7.days.ago
      
      episodes_synced_at < AIRING_STALE_THRESHOLD.ago
    end
    
    # Find from cache or queue API fetch
    def self.find_or_fetch(mal_id)
      record = find_by(mal_id: mal_id)
      
      if record.nil?
        # Not in cache, need to fetch synchronously first time
        nil
      elsif record.stale?
        # In cache but stale, return stale data and queue refresh
        Jobs.enqueue(:anime_sync, mal_id: mal_id)
        record
      else
        # Fresh cache hit
        record
      end
    end
    
    # Convert to API-compatible format
    def to_api_hash
      # Prefer local image if available
      effective_image_url = local_image_url.presence || image_url
      
      {
        'mal_id' => mal_id,
        'slug' => title.to_s.parameterize,
        'title' => title,
        'title_english' => title_english,
        'title_japanese' => title_japanese,
        'synopsis' => synopsis,
        'images' => {
          'jpg' => { 'large_image_url' => effective_image_url }
        },
        'score' => score&.to_f,
        'scored_by' => scored_by,
        'rank' => rank,
        'popularity' => popularity,
        'members' => members,
        'episodes' => episodes_total,
        'status' => api_status_string,
        'aired' => {
          'from' => aired_from&.iso8601,
          'to' => aired_to&.iso8601,
          'string' => format_aired_string(aired_from, aired_to)
        },
        'season' => season,
        'year' => year,
        'type' => anime_type,
        'source' => source,
        'rating' => rating,
        'duration' => duration_minutes ? "#{duration_minutes} min per ep" : nil,
        'genres' => (genres || []).map { |g| { 'name' => g } },
        'studios' => (studios || []).map { |s| { 'name' => s } },
        'producers' => (producers || []).map { |p| { 'name' => p } },
        'themes' => (themes || []).map { |t| { 'name' => t } },
        'demographics' => (demographics || []).map { |d| { 'name' => d } },
        'trailer' => raw_jikan&.dig('trailer') || map_anilist_trailer(raw_anilist&.dig('anilist', 'trailer')),
        'anilist' => raw_anilist&.dig('anilist'),
        'streaming' => raw_anilist&.dig('streaming'),
        '_cached' => true,
        '_cached_at' => last_api_sync_at&.iso8601,
        '_local_image' => local_image_url.present?
      }
    end
    
    private
    
    def format_aired_string(from, to)
      return "N/A" if from.nil?
      
      from_str = from.strftime("%b %-d, %Y")
      to_str = to ? to.strftime("%b %-d, %Y") : "?"
      
      "#{from_str} to #{to_str}"
    end

    def api_status_string
      case airing_status
      when 'airing' then 'Currently Airing'
      when 'finished' then 'Finished Airing'
      when 'upcoming' then 'Not yet aired'
      else airing_status
      end
    end

    def map_anilist_trailer(trailer_data)
      return nil unless trailer_data && trailer_data['site'] == 'youtube'
      
      {
        "youtube_id" => trailer_data['id'],
        "url" => "https://www.youtube.com/watch?v=#{trailer_data['id']}",
        "embed_url" => "https://www.youtube-nocookie.com/embed/#{trailer_data['id']}"
      }
    end
  end
end
