# frozen_string_literal: true

module ::Jobs
  class AnimeEpisodeDiscussion < ::Jobs::Scheduled
    every 6.hours

    def execute(args)
      return unless SiteSetting.anime_database_enabled
      return unless SiteSetting.anime_auto_episode_discussions
      return if SiteSetting.anime_episode_category.blank?

      Rails.logger.info("[Anime Plugin] Checking for new episodes...")

      check_recent_episodes
    end

    private

    def check_recent_episodes
      # Get schedule from Jikan API (upcoming and recent episodes)
      begin
        schedules_data = fetch_schedules
        
        return unless schedules_data && schedules_data["data"]

        anime_with_new_episodes = schedules_data["data"]
        
        anime_with_new_episodes.each do |anime_data|
          process_anime_episode(anime_data)
        end

        Rails.logger.info("[Anime Plugin] Episode check complete. Processed #{anime_with_new_episodes.count} anime.")
      rescue => e
        Rails.logger.error("[Anime Plugin] Error checking episodes: #{e.message}")
      end
    end

    def fetch_schedules
      # Fetch from Jikan v4 schedules endpoint
      url = "https://api.jikan.moe/v4/schedules"
      
      response = Excon.get(
        url,
        headers: { "Accept" => "application/json" },
        connect_timeout: 10,
        read_timeout: 10
      )

      return nil unless response.status == 200

      JSON.parse(response.body)
    rescue => e
      Rails.logger.error("[Anime Plugin] Failed to fetch schedules: #{e.message}")
      nil
    end

    def process_anime_episode(anime_data)
      anime_id = anime_data["mal_id"].to_s
      anime_title = anime_data["title"]
      
      # broadcast_time is when the episode airs
      broadcast_time = parse_broadcast_time(anime_data["broadcast"])
      
      return unless broadcast_time
      return unless recently_aired?(broadcast_time)

      # For currently airing anime, we need to determine the current episode
      # This is approximate - ideally we'd have episode-specific data
      current_episode = estimate_current_episode(anime_data)
      
      return unless current_episode

      # Check if we already have a discussion for this episode
      existing = AnimeDatabase::AnimeEpisodeTopic.find_by(
        anime_id: anime_id,
        episode_number: current_episode
      )

      return if existing

      # Create discussion topic
      Rails.logger.info("[Anime Plugin] Creating discussion for #{anime_title} Episode #{current_episode}")
      
      AnimeDatabase::AnimeEpisodeTopic.create_discussion_topic(
        anime_id: anime_id,
        episode_number: current_episode,
        anime_title: anime_title,
        aired_at: broadcast_time
      )

      # Notify watchlist users if enabled
      notify_watchlist_users(anime_id, anime_title, current_episode) if SiteSetting.anime_notify_watchlist_users
    end

    def parse_broadcast_time(broadcast_data)
      return nil unless broadcast_data && broadcast_data["time"]

      # Broadcast time is in JST, approximate with current day
      # This is a simplification - full implementation would parse day/time properly
      Time.current
    rescue StandardError
      nil
    end

    def recently_aired?(broadcast_time)
      # Check if within the last check interval + buffer
      hours_ago = SiteSetting.anime_episode_check_interval + 1
      broadcast_time > hours_ago.hours.ago && broadcast_time <= Time.current
    end

    def estimate_current_episode(anime_data)
      # This is a simplified estimation
      # In practice, you'd need more sophisticated logic or additional API calls
      # For now, we'll use the aired episodes count if available
      aired_episodes = anime_data["aired"]&.dig("prop", "from", "episode")
      aired_episodes || 1
    end

    def notify_watchlist_users(anime_id, anime_title, episode_number)
      # Find users who have this anime on their watchlist with status "watching"
      user_ids = DB.query_single(
        "SELECT DISTINCT user_id FROM anime_watchlists WHERE anime_id = ? AND status = 'watching'",
        anime_id
      )

      return if user_ids.empty?

      # Create notification for each user
      user_ids.each do |user_id|
        begin
          Notification.create!(
            notification_type: Notification.types[:custom],
            user_id: user_id,
            data: {
              message: "anime.new_episode",
              anime_title: anime_title,
              episode_number: episode_number,
              anime_id: anime_id
            }.to_json
          )
        rescue => e
          Rails.logger.error("[Anime Plugin] Failed to notify user #{user_id}: #{e.message}")
        end
      end

      Rails.logger.info("[Anime Plugin] Notified #{user_ids.count} users about #{anime_title} Episode #{episode_number}")
    end
  end
end
