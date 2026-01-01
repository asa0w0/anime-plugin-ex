require_dependency "application_controller"

module AnimeDatabase
  class AnimeController < ::ApplicationController
    requires_plugin "anime-plugin-ex"

    def index
      query = params[:q].presence
      type = params[:type].presence
      status = params[:status].presence
      genres = params[:genre].presence
      order_by = params[:sort].presence || "score"
      sort_order = params[:order].presence || "desc"

      cache_key = "anime_list_search_#{query}_#{type}_#{status}_#{genres}_#{order_by}_#{sort_order}"
      
      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        if query.present? || type.present? || status.present? || genres.present?
          url = "https://api.jikan.moe/v4/anime?limit=24"
          url += "&q=#{CGI.escape(query)}" if query
          url += "&type=#{CGI.escape(type)}" if type
          url += "&status=#{CGI.escape(status)}" if status
          url += "&genres=#{CGI.escape(genres)}" if genres
          url += "&order_by=#{CGI.escape(order_by)}&sort=#{CGI.escape(sort_order)}"
          fetch_from_api(url)
        else
          # Fallback to top anime if no filters
          fetch_from_api("https://api.jikan.moe/v4/top/anime?limit=24")
        end
      end

      # Safety check: Jikan errors often return 'data' as nil or include an 'error' field
      if response.nil? || response["error"] || !response.is_a?(Hash) || !response["data"]
        response = { "data" => [] }
      end

      render json: response
    end

    def show
      id = params[:id]
      cache_key = "anime_details_#{id}"

      begin
        response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
          url = "https://api.jikan.moe/v4/anime/#{id}/full"
          fetch_from_api(url)
        end
        
        # Ensure response is a Hash
        response = { "data" => {} } unless response.is_a?(Hash)
        response = response.dup

        # Find all topics associated with this anime
        topic_ids = ::TopicCustomField.where(name: "anime_mal_id", value: id.to_s).pluck(:topic_id)
        topics = ::Topic.where(id: topic_ids, deleted_at: nil)
        
        topics_data = topics.map do |t|
          {
            id: t.id,
            title: t.title,
            slug: t.slug,
            post_count: t.posts_count,
            last_posted_at: t.last_posted_at
          }
        end

        # Add watchlist status if user is logged in
        watchlist_status = nil
        if current_user
          entry = DB.query_single("SELECT status FROM anime_watchlists WHERE user_id = ? AND anime_id = ?", current_user.id, id.to_s).first
          watchlist_status = entry
        end

        if response["data"].is_a?(Hash)
          response["data"]["topics"] = topics_data
          response["data"]["watchlist_status"] = watchlist_status
        else
          response["topics"] = topics_data
          response["watchlist_status"] = watchlist_status
        end

        render json: response
      rescue => e
        Rails.logger.error("Anime Plugin Show Error: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "Internal Server Error", message: e.message }, status: 500
      end
    end
    
    def episodes
      anime_id = params[:id]
      
      # Fetch episode discussions from database
      episode_topics = AnimeDatabase::AnimeEpisodeTopic
        .for_anime(anime_id)
        .recent
        .includes(:topic)
        .limit(50)
      
      episodes_data = episode_topics.map do |et|
        {
          episode_number: et.episode_number,
          aired_at: et.aired_at,
          topic_id: et.topic_id,
          topic_title: et.topic&.title,
          topic_url: "/t/#{et.topic&.slug}/#{et.topic_id}",
          post_count: et.topic&.posts_count || 0
        }
      end
      
      render json: { episodes: episodes_data }
    rescue => e
      Rails.logger.error("Anime Plugin Episodes Error: #{e.message}")
      render json: { episodes: [] }
    end
    
    def seasons
      year = params[:year]
      season = params[:season]
      
      cache_key = if year.present? && season.present?
                    "anime_seasons_#{year}_#{season}"
                  else
                    "anime_seasons_now"
                  end

      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        url = if year.present? && season.present?
                "https://api.jikan.moe/v4/seasons/#{year}/#{season}"
              else
                "https://api.jikan.moe/v4/seasons/now"
              end
        fetch_from_api(url)
      end

      render json: response
    end

    def watchlist
      user = if params[:username].present?
               User.find_by_username(params[:username])
             else
               current_user
             end

      return render json: { error: "User not found or not logged in" }, status: 404 unless user

      list = DB.query("SELECT * FROM anime_watchlists WHERE user_id = ? ORDER BY updated_at DESC", user.id)
      
      render json: {
        data: list.map { |row|
          {
            anime_id: row.anime_id,
            status: row.status,
            title: row.title,
            image_url: row.image_url
          }
        }
      }
    end

    def update_watchlist
      return render json: { error: "Not logged in" }, status: 403 unless current_user
      return render json: { error: "Insufficient permissions" }, status: 403 unless current_user.trust_level >= SiteSetting.anime_min_trust_level
      
      anime_id = params[:anime_id].to_s
      status = params[:status]
      title = params[:title]
      image_url = params[:image_url]

      DB.exec(<<~SQL, current_user.id, anime_id, status, title, image_url, Time.now, Time.now)
        INSERT INTO anime_watchlists (user_id, anime_id, status, title, image_url, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (user_id, anime_id)
        DO UPDATE SET status = EXCLUDED.status, updated_at = EXCLUDED.updated_at
      SQL

      render json: { success: true, status: status }
    end

    def remove_watchlist
      return render json: { error: "Not logged in" }, status: 403 unless current_user
      
      DB.exec("DELETE FROM anime_watchlists WHERE user_id = ? AND anime_id = ?", current_user.id, params[:anime_id].to_s)
      
      render json: { success: true }
    end

    def calendar
      cache_key = "anime_schedule"
      
      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        # Fetch all pages from Jikan schedules endpoint
        all_anime = []
        page = 1
        
        loop do
          url = "https://api.jikan.moe/v4/schedules?page=#{page}"
          page_response = fetch_from_api(url)
          
          break unless page_response && page_response["data"]
          
          all_anime.concat(page_response["data"])
          
          # Check if there are more pages
          has_next_page = page_response.dig("pagination", "has_next_page")
          break unless has_next_page
          
          page += 1
          sleep(0.3) # Rate limiting for Jikan API
        end
        
        # Deduplicate by mal_id
        unique_anime = all_anime.uniq { |anime| anime["mal_id"] }
        
        { "data" => unique_anime }
      end

      # Ensure response is a Hash
      response = { "data" => [] } unless response.is_a?(Hash)
      response = response.dup

      # Add user's watchlist if logged in
      if current_user
        watchlist_anime_ids = DB.query_single(
          "SELECT anime_id FROM anime_watchlists WHERE user_id = ? AND status = 'watching'",
          current_user.id
        )
        response["watchlist_anime_ids"] = watchlist_anime_ids
      else
        response["watchlist_anime_ids"] = []
      end

      render json: response
    end

    private

    def fetch_from_api(url)
      begin
        fd = FinalDestination.new(url)
        endpoint = fd.resolve
        
        return { error: "Invalid URL" } unless endpoint

        response = Excon.get(
          endpoint,
          headers: { "User-Agent" => "Discourse Anime Plugin" },
          expects: [200, 404],
          timeout: 5
        )
        
        JSON.parse(response.body)
      rescue => e
        Rails.logger.error("Anime Plugin API Error: #{e.message}")
        { error: "Failed to fetch data from API" }
      end
    end
  end
end
