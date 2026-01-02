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

      page = params[:page].presence || 1
      
      cache_key = "anime_list_search_#{query}_#{type}_#{status}_#{genres}_#{order_by}_#{sort_order}_p#{page}"
      
      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        if query.present? || type.present? || status.present? || genres.present?
          url = "https://api.jikan.moe/v4/anime?limit=24&page=#{page}"
          url += "&q=#{CGI.escape(query)}" if query
          url += "&type=#{CGI.escape(type)}" if type
          url += "&status=#{CGI.escape(status)}" if status
          url += "&genres=#{CGI.escape(genres)}" if genres
          url += "&order_by=#{CGI.escape(order_by)}&sort=#{CGI.escape(sort_order)}"
          fetch_from_api(url)
        else
          # Fallback to top anime if no filters
          fetch_from_api("https://api.jikan.moe/v4/top/anime?limit=24&page=#{page}")
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
        raw_response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
          url = "https://api.jikan.moe/v4/anime/#{id}/full"
          res = fetch_from_api(url)
          
          # Don't cache error responses or 404s from Jikan
          if res.is_a?(Hash) && (res["error"] || (res["status"] && res["status"].to_i >= 400) || !res["data"])
            # Return a special marker to avoid caching
            { _api_error: true, status: res["status"] || 500, message: res["message"] || "API Error" }
          else
            res
          end
        end
        
        if raw_response.nil? || raw_response[:_api_error] || raw_response["_api_error"] || !raw_response.is_a?(Hash) || !raw_response["data"]
          Rails.logger.warn("[Anime Plugin] API data missing or error for ID #{id}. Response: #{raw_response.inspect}")
          Discourse.cache.delete(cache_key) # Ensure we don't keep a bad record
          return render json: { error: "Anime data not available", status: 404 }, status: 404
        end

        # We have valid data from Jikan
        anime_data = raw_response["data"].dup
        Rails.logger.debug("[Anime Plugin] Valid anime data found for #{id}: #{anime_data['title']}")

        # Fetch additional data from AniList and TMDB
        anilist_data = AnilistService.fetch_by_mal_id(id)
        tmdb_data = nil
        
        if SiteSetting.anime_enable_tmdb && anime_data["title"]
          tmdb_search = TmdbService.search_anime(anime_data["title"])
          if tmdb_search && tmdb_search["id"]
            tmdb_data = TmdbService.fetch_details(tmdb_search["id"])
          end
        end

        # Merge AniList data
        if anilist_data
          anime_data["anilist"] = {
            id: anilist_data["id"],
            url: anilist_data["siteUrl"],
            score: anilist_data["averageScore"],
            popularity: anilist_data["popularity"],
            favourites: anilist_data["favourites"],
            tags: anilist_data["tags"],
            characters: anilist_data["characters"]&.dig("nodes"),
            relations: anilist_data["relations"]&.dig("edges"),
            streaming: anilist_data["streamingEpisodes"],
            external_links: anilist_data["externalLinks"]
          }
        end

        # Merge TMDB data
        if tmdb_data
          anime_data["tmdb"] = {
            id: tmdb_data["id"],
            backdrop_path: tmdb_data["backdrop_path"],
            poster_path: tmdb_data["poster_path"],
            cast: tmdb_data.dig("credits", "cast")&.take(10),
            crew: tmdb_data.dig("credits", "crew")&.take(5),
            videos: tmdb_data.dig("videos", "results"),
            posters: tmdb_data.dig("images", "posters")&.take(6),
            backdrops: tmdb_data.dig("images", "backdrops")&.take(6)
          }
        end

        # Find general topics (exclude those with episode numbers)
        topic_ids = ::TopicCustomField.where(name: "anime_mal_id", value: id.to_s).pluck(:topic_id)
        episode_topic_ids = ::TopicCustomField.where(name: "anime_episode_number", topic_id: topic_ids).pluck(:topic_id)
        general_topic_ids = topic_ids - episode_topic_ids
        
        topics = ::Topic.where(id: general_topic_ids, deleted_at: nil).order(created_at: :desc).limit(20)
        
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

        # Merge local data into anime_data
        anime_data["topics"] = topics_data
        anime_data["watchlist_status"] = watchlist_status

        render json: { "data" => anime_data }
      rescue => e
        Rails.logger.error("Anime Plugin Show Error: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "Internal Server Error", message: e.message }, status: 500
      end
    end

    def create_episode_discussion
      raise Discourse::NotLoggedIn unless current_user

      anime_id = params[:anime_id]
      episode_number = params[:episode_number]&.to_i
      anime_title = params[:anime_title]
      category_id = params[:category_id]&.to_i || SiteSetting.anime_episode_category&.to_i

      if anime_id.blank? || episode_number.nil? || episode_number <= 0
        return render json: { error: "Invalid parameters" }, status: 400
      end

      # Check if discussion already exists
      existing = AnimeDatabase::AnimeEpisodeTopic.find_by(anime_id: anime_id, episode_number: episode_number)
      if existing && existing.topic_id && existing.topic
        return render json: { 
          topic_id: existing.topic_id,
          topic_url: "/t/#{existing.topic.slug}/#{existing.topic_id}",
          already_exists: true
        }
      end

      # Create the topic
      title = "[Anime] #{anime_title} - Episode #{episode_number} Discussion"
      body = params[:body] || "Episode #{episode_number} discussion"

      begin
        topic = Topic.create!(
          title: title,
          user: current_user,
          category_id: category_id,
          archetype: Archetype.default
        )

        # Set custom fields
        topic.custom_fields["anime_mal_id"] = anime_id.to_s
        topic.custom_fields["anime_episode_number"] = episode_number
        topic.save_custom_fields

        # Create first post
        post = PostCreator.create!(
          current_user,
          topic_id: topic.id,
          raw: body,
          skip_validations: false
        )

        # Link to anime_episode_topics
        ep_topic = AnimeDatabase::AnimeEpisodeTopic.find_or_initialize_by(
          anime_id: anime_id.to_s,
          episode_number: episode_number
        )
        ep_topic.topic_id = topic.id
        ep_topic.aired_at ||= Time.current
        ep_topic.save!

        # Clear cache
        Discourse.cache.delete("anime_episodes_list_v2_#{anime_id}")

        Rails.logger.info("[Anime Plugin] Created episode discussion: anime_id=#{anime_id} ep=#{episode_number} topic=#{topic.id}")

        render json: { 
          topic_id: topic.id,
          topic_url: "/t/#{topic.slug}/#{topic.id}",
          success: true
        }
      rescue => e
        Rails.logger.error("[Anime Plugin] Error creating episode discussion: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        render json: { error: "Failed to create topic: #{e.message}" }, status: 500
      end
    end
    
    def episodes
      anime_id = params[:id]
      cache_key = "anime_episodes_list_v3_#{anime_id}"

      # Fetch from API with cache
      api_episodes = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        all_episodes = []
        page = 1
        has_next = true
        fetch_success = false

        Rails.logger.info("[Anime Plugin] Fetching episodes for anime_id=#{anime_id} from API...")

        # Fetch all pages of episodes
        while has_next && page <= 5
          url = "https://api.jikan.moe/v4/anime/#{anime_id}/episodes?page=#{page}"
          response = fetch_from_api(url)
          
          if response.is_a?(Hash) && response["data"].is_a?(Array)
            all_episodes.concat(response["data"])
            has_next = response.dig("pagination", "has_next_page") || false
            fetch_success = true
            
            Rails.logger.debug("[Anime Plugin] Fetched page #{page} for anime_id=#{anime_id}. Found #{response["data"].length} episodes. has_next=#{has_next}")
          else
            Rails.logger.error("[Anime Plugin] Failed to fetch episodes page #{page} for anime_id=#{anime_id}. Response: #{response.inspect}")
            break
          end
          
          page += 1
          sleep(0.5) if has_next
        end

        # Only cache if we actually got some data or if the API confirmed 0 episodes
        if fetch_success && (all_episodes.present? || page > 1)
          all_episodes
        else
          nil # Returning nil prevents caching in most Discourse.cache setups
        end
      end

      api_episodes ||= []
      
      # If still empty after cache attempt (e.g. nil returned from block), 
      # we might want to log it specifically
      if api_episodes.empty?
        Rails.logger.warn("[Anime Plugin] Episode list is empty for anime_id=#{anime_id} after API fetch attempt.")
      end
      
      # Fetch local episode discussions
      local_discussions = AnimeDatabase::AnimeEpisodeTopic
        .for_anime(anime_id)
        .includes(:topic)
        .to_a
        .index_by(&:episode_number)

      # Merge API data with local discussions
      merged_episodes = api_episodes.map do |ep|
        ep_num = ep["mal_id"]
        local_et = local_discussions[ep_num]

        {
          episode_number: ep_num,
          title: ep["title"],
          title_japanese: ep["title_japanese"],
          duration: ep["duration"],
          aired_at: ep["aired"] || local_et&.aired_at,
          filler: ep["filler"],
          recap: ep["recap"],
          forum_topic: local_et ? {
            topic_id: local_et.topic_id,
            topic_title: local_et.topic&.title,
            topic_url: "/t/#{local_et.topic&.slug}/#{local_et.topic_id}",
            post_count: local_et.topic&.posts_count || 0
          } : nil
        }
      end

      # Add local discussions that aren't in the API list (just in case)
      local_discussions.each do |ep_num, local_et|
        unless merged_episodes.any? { |me| me[:episode_number] == ep_num }
          merged_episodes << {
            episode_number: ep_num,
            title: "Episode #{ep_num}",
            aired_at: local_et.aired_at,
            forum_topic: {
              topic_id: local_et.topic_id,
              topic_title: local_et.topic&.title,
              topic_url: "/t/#{local_et.topic&.slug}/#{local_et.topic_id}",
              post_count: local_et.topic&.posts_count || 0
            }
          }
        end
      end

      # Sort by episode number
      merged_episodes.sort_by! { |e| e[:episode_number] }

      Rails.logger.info("[Anime Plugin] Returning #{merged_episodes.length} merged episodes for anime_id=#{anime_id} (API: #{api_episodes.length}, Local extras: #{merged_episodes.length - api_episodes.length})")

      render json: { episodes: merged_episodes }
    rescue => e
      Rails.logger.error("Anime Plugin Episodes Error: #{e.message}")
      render json: { episodes: [] }
    end
    
    def seasons
      year = params[:year]
      season = params[:season]
      
      # Validate year and season if provided
      if year.present? || season.present?
        valid_seasons = %w[winter spring summer fall]
        
        # Year must be numeric and reasonable (1900-2100)
        if year.present? && (year.to_s !~ /^\d{4}$/ || year.to_i < 1900 || year.to_i > 2100)
          return render json: { error: "Invalid year parameter" }, status: 400
        end
        
        # Season must be one of the allowed values
        if season.present? && !valid_seasons.include?(season.to_s.downcase)
          return render json: { error: "Invalid season parameter. Must be: #{valid_seasons.join(', ')}" }, status: 400
        end
      end
      
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

      # Privacy check: Only allow viewing other users' watchlists if setting is enabled
      if user != current_user && !SiteSetting.anime_public_watchlists
        return render json: { error: "This watchlist is private" }, status: 403
      end

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

      # Validate status enum
      valid_statuses = %w[watching completed planned plan_to_watch on_hold dropped]
      unless valid_statuses.include?(status)
        return render json: { error: "Invalid status. Must be: #{valid_statuses.join(', ')}" }, status: 400
      end

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
      cache_key = "anime_schedule_anilist"
      
      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        anilist_items = AnilistService.fetch_airing_schedule(7)
        
        if anilist_items.present?
          # Map AniList schedule to Jikan-like structure
          mapped_anime = anilist_items.map do |item|
            media = item['media']
            next if media['idMal'].blank?

            # Convert airingAt to synthesized broadcast
            airing_time = Time.at(item['airingAt']).in_time_zone("Tokyo")
            
            {
              "mal_id" => media['idMal'],
              "title" => media['title']['english'] || media['title']['romaji'],
              "images" => {
                "jpg" => { "large_image_url" => media['coverImage']['large'] }
              },
              "members" => media['popularity'],
              "score" => media['averageScore'] ? (media['averageScore'].to_f / 10).round(2) : nil,
              "synopsis" => media['description'],
              "genres" => (media['genres'] || []).map { |g| { "name" => g } },
              "status" => media['status'],
              "broadcast" => {
                "day" => airing_time.strftime("%A"),
                "time" => airing_time.strftime("%H:%M"),
                "timezone" => "Asia/Tokyo"
              },
              "airing_at" => item['airingAt'] # Pass through for precise countdown
            }
          end.compact

          # Deduplicate by mal_id (e.g. if multiple episodes air in the same week)
          mapped_anime = mapped_anime.uniq { |a| a['mal_id'] }

          # Sort by popularity to show major titles first
          mapped_anime.sort_by! { |a| -(a['members'] || 0) }
          
          { "data" => mapped_anime }
        else
          # Fallback to Jikan if AniList fails
          fetch_from_api("https://api.jikan.moe/v4/schedules?limit=25")
        end
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

    def fetch_from_api(url, retry_count = 2)
      begin
        fd = FinalDestination.new(url)
        endpoint = fd.resolve
        
        return { error: "Invalid URL" } unless endpoint

        response = Excon.get(
          endpoint,
          headers: { "User-Agent" => "Discourse Anime Plugin" },
          expects: [200, 404, 429],
          connect_timeout: 10,
          read_timeout: 15,
          write_timeout: 10
        )
        
        # Rate limited - wait and retry
        if response.status == 429 && retry_count > 0
          Rails.logger.warn("[Anime Plugin] Rate limited (429), waiting 1.5s before retry...")
          sleep(1.5)
          return fetch_from_api(url, retry_count - 1)
        end

        JSON.parse(response.body)
      rescue => e
        # Retry on timeout or socket errors
        if retry_count > 0 && (e.is_a?(Excon::Error::Timeout) || e.is_a?(Excon::Error::Socket) || e.message.to_s.include?("timeout"))
          Rails.logger.warn("[Anime Plugin] Timeout/Socket error, retrying (#{retry_count} left)... Error: #{e.message}")
          sleep(1)
          return fetch_from_api(url, retry_count - 1)
        end
        
        Rails.logger.error("[Anime Plugin] API Error after all retries: #{e.class} - #{e.message}")
        { error: "Failed to fetch data from API", message: e.message }
      end
    end

  end
end
