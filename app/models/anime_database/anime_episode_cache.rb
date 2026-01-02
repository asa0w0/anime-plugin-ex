# frozen_string_literal: true

module AnimeDatabase
  class AnimeEpisodeCache < ActiveRecord::Base
    self.table_name = 'anime_episodes_cache'
    
    scope :for_anime, ->(mal_id) { where(mal_id: mal_id).order(:episode_number) }
    scope :aired, -> { where.not(aired_at: nil).where('aired_at <= ?', Time.current) }
    scope :upcoming, -> { where('aired_at > ?', Time.current) }
    
    # Convert to API-compatible format
    def to_api_hash
      {
        'mal_id' => episode_number,
        'title' => title,
        'title_japanese' => title_japanese,
        'title_romanji' => title_romanji,
        'aired' => aired_at&.iso8601,
        'duration' => duration_seconds,
        'filler' => filler,
        'recap' => recap,
        'synopsis' => synopsis,
        '_cached' => true
      }
    end
    
    # Bulk upsert episodes from API response
    def self.upsert_from_api(mal_id, episodes_data)
      return if episodes_data.blank?
      
      records = episodes_data.map do |ep|
        {
          mal_id: mal_id,
          episode_number: ep['mal_id'],
          title: ep['title'],
          title_japanese: ep['title_japanese'],
          title_romanji: ep['title_romanji'],
          aired_at: ep['aired'] ? Time.parse(ep['aired']) : nil,
          duration_seconds: parse_duration(ep['duration']),
          filler: ep['filler'] || false,
          recap: ep['recap'] || false,
          synopsis: ep['synopsis'],
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      upsert_all(
        records,
        unique_by: [:mal_id, :episode_number],
        update_only: [:title, :title_japanese, :title_romanji, :aired_at, :duration_seconds, :filler, :recap, :synopsis, :updated_at]
      )
    end
    
    def self.parse_duration(duration_str)
      return nil unless duration_str.present?
      
      # Parse formats like "24 min" or "24:00"
      if duration_str.include?(':')
        parts = duration_str.split(':')
        (parts[0].to_i * 60) + parts[1].to_i
      elsif duration_str =~ /(\d+)\s*min/
        $1.to_i * 60
      else
        nil
      end
    end
    private_class_method :parse_duration
  end
end
