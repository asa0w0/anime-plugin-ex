require_dependency "application_controller"

module AnimeDatabase
  class AnimeController < ::ApplicationController
    requires_plugin "anime-plugin-ex"

    def index
      query = params[:q].presence
      page = params[:page].presence || 1
      
      cache_key = "anime_list_search_v6_#{query}_p#{page}"
      
      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        if query.present?
          if SiteSetting.anime_enable_anilist
            # Search via AniList
            anilist_results = AnilistService.search(query)
            
            # Map AniList to our internal format
            mapped_data = anilist_results.map do |item|
              # Generate slug from title
              title = item.dig('title', 'english') || item.dig('title', 'romaji')
              slug = title.parameterize
              
              {
                "mal_id" => item['idMal'] || "al-#{item['id']}",
                "anilist_id" => item['id'],
                "slug" => slug,
                "title" => title,
                "images" => {
                  "jpg" => { 
                    "large_image_url" => item.dig('coverImage', 'large'),
                    "image_url" => item.dig('coverImage', 'large')
                  }
                },
                "score" => item['averageScore'] ? (item['averageScore'].to_f / 10).round(2) : nil,
                "popularity" => item['popularity'],
                "genres" => (item['genres'] || []).map { |g| { "name" => g } },
                "synopsis" => item['description'],
                "status" => item['status'],
                "is_numeric_id" => item['idMal'].present?
              }
            end
            { "data" => mapped_data }
          else
            # Fallback to Jikan
            url = "https://api.jikan.moe/v4/anime?q=#{CGI.escape(query)}&limit=24&page=#{page}"
            res = fetch_from_api(url)
            if res.is_a?(Hash) && res["data"].present?
              res["data"].each do |a|
                a["slug"] = a["title"].to_s.parameterize
                a["is_numeric_id"] = true
              end
            end
            res
          end
        else
          # Fallback to top anime via Jikan for discovery
          res = fetch_from_api("https://api.jikan.moe/v4/top/anime?limit=24&page=#{page}")
          if res.is_a?(Hash) && res["data"].present?
            res["data"].each do |a|
              a["slug"] = a["title"].to_s.parameterize
              a["is_numeric_id"] = true
            end
          end
          res
        end
      end

      if response.is_a?(Hash) && response["data"].present?
        response = response.deep_dup
        response["data"] = response["data"].map do |a|
          title = a["title"] || a["title_english"] || a["title_japanese"]
          a["slug"] = title.to_s.parameterize if a["slug"].blank? && title.present?
          a["is_numeric_id"] = true if a["is_numeric_id"].nil?
          a
        end
        merge_local_images(response["data"])
      end

      render json: response
    end

    def show
      id = resolve_params_id(params[:id])
      
      
      begin
        # 1. Try local cache first
        cached_anime = AnimeDatabase::AnimeCache.find_by(mal_id: id)
        
        if cached_anime && !cached_anime.stale?
          anime_data = cached_anime.to_api_hash
        else
          # 2. Fetch from APIs
          cache_key = "anime_details_v3_#{id}"
          raw_response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
            res = nil
            # Try AniList Primary
            if SiteSetting.anime_enable_anilist
              res = id.to_s.start_with?("al-") ? 
                    AnilistService.fetch_by_id(id.split("-").last) : 
                    AnilistService.fetch_by_mal_id(id)
            end
            
            if res
              { "data" => map_anilist_to_internal(res) }
            elsif id.to_s !~ /\Aal-/
              # Fallback to Jikan
              jikan_res = fetch_from_api("https://api.jikan.moe/v4/anime/#{id}/full")
              jikan_res = fetch_from_api("https://api.jikan.moe/v4/anime/#{id}") if jikan_res&.dig("status") == 404
              jikan_res
            else
              nil
            end
          end

          if raw_response&.dig("data")
            anime_data = raw_response["data"].dup
            Jobs.enqueue(:anime_sync_job, mal_id: id) if id.to_s =~ /\A\d+\z/
          elsif cached_anime
            anime_data = cached_anime.to_api_hash
          else
            return render json: { error: "Anime data not available" }, status: 404
          end
        end

        # Ensure slug is present for SEO
        anime_data["slug"] ||= (anime_data["title"] || "").parameterize
        merge_local_images(anime_data)

        # Add TMDB data if enabled and missing
        if SiteSetting.anime_enable_tmdb && !anime_data["tmdb"]
          tmdb_search = TmdbService.search_anime(anime_data["title"])
          if tmdb_search&.dig("id")
            tmdb_details = TmdbService.fetch_details(tmdb_search["id"])
            if tmdb_details
              anime_data["tmdb"] = {
                id: tmdb_details["id"],
                backdrop_path: tmdb_details["backdrop_path"],
                poster_path: tmdb_details["poster_path"],
                cast: tmdb_details.dig("credits", "cast")&.take(10),
                videos: tmdb_details.dig("videos", "results")
              }
            end
          end
        end

        # Discussions & Watchlist
        topic_ids = ::TopicCustomField.where(name: "anime_mal_id", value: id.to_s).pluck(:topic_id)
        episode_topic_ids = ::TopicCustomField.where(name: "anime_episode_number", topic_id: topic_ids).pluck(:topic_id)
        topics = ::Topic.where(id: topic_ids - episode_topic_ids, deleted_at: nil).order(created_at: :desc).limit(20)
        
        anime_data["topics"] = topics.map { |t| { id: t.id, title: t.title, slug: t.slug, post_count: t.posts_count, last_posted_at: t.last_posted_at } }
        
        if current_user
          row = DB.query("SELECT status, episodes_watched, total_episodes FROM anime_watchlists WHERE user_id = ? AND anime_id = ?", current_user.id, id.to_s).first
          anime_data["watchlist_status"] = { status: row.status, episodes_watched: row.episodes_watched || 0, total_episodes: row.total_episodes || 0 } if row
        end

        # SEO
        title_text = anime_data['title_english'] || anime_data['title']
        @title = "#{title_text} | Anime Database"
        @description = (anime_data['synopsis'] || "").truncate(200)
        @canonical_url = "#{Discourse.base_url}/anime/#{anime_data['slug']}"
        response.headers["X-Discourse-Title"] = @title

        render json: { "data" => anime_data }
      rescue => e
        Rails.logger.error("Anime Plugin Show Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        render json: { error: "Internal Server Error" }, status: 500
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
      anime_id = resolve_params_id(params[:id])
      
      # Try local cache first
      cached_episodes = AnimeDatabase::AnimeEpisodeCache.for_anime(anime_id).to_a
      anime_cache = AnimeDatabase::AnimeCache.find_by(mal_id: anime_id)
      
      if cached_episodes.present? && anime_cache && !anime_cache.episodes_stale?
        # Fresh cache hit - use local data
        api_episodes = cached_episodes.map(&:to_api_hash)
        jikan_streaming = []
        if anime_cache
          jikan_streaming += (anime_cache.raw_anilist&.dig("streaming") || [])
          jikan_streaming += (anime_cache.raw_jikan&.dig("streaming") || [])
        end
      else
        # Cache miss or stale - fetch from API
        cache_key = "anime_episodes_v6_#{anime_id}"
        jikan_streaming = []
        
        api_episodes = Discourse.cache.read(cache_key)
        
        # If cache is missing OR suspiciously empty for an aired show
        if api_episodes.nil? || (api_episodes.empty? && (anime_cache&.episodes_total || 0) > 0)
          Rails.logger.warn("[Anime Plugin] Episode cache miss/empty for #{anime_id}. Fetching...")
          
          # 1. Try Jikan
          all_episodes = []
          if anime_id.to_s =~ /\A\d+\z/
            page = 1
            has_next = true
            while has_next && page <= 3
              res = fetch_from_api("https://api.jikan.moe/v4/anime/#{anime_id}/episodes?page=#{page}")
              if res.is_a?(Hash) && res["data"].is_a?(Array)
                all_episodes.concat(res["data"])
                has_next = res.dig("pagination", "has_next_page") || false
              else
                break
              end
              page += 1
            end
          end
          
          # 2. Try TMDB fallback if Jikan failed
          if all_episodes.empty? && SiteSetting.anime_enable_tmdb
             tmdb_res = TmdbService.search_anime(anime_cache&.title || params[:id])
             if tmdb_res&.dig("id")
               details = TmdbService.fetch_details(tmdb_res["id"])
               # Map TMDB seasons to flat episode list if needed
               # (For now, just a placeholder as Jikan is primary)
             end
          end
          
          if all_episodes.present?
            Discourse.cache.write(cache_key, all_episodes, expires_in: 24.hours)
            api_episodes = all_episodes
            Jobs.enqueue(:episode_sync_job, mal_id: anime_id)
          end
        end

        # Get streaming info from cache if available
        jikan_streaming = []
        if anime_cache
          jikan_streaming += (anime_cache.raw_anilist&.dig("streaming") || [])
          jikan_streaming += (anime_cache.raw_jikan&.dig("streaming") || [])
        end
        api_episodes ||= []
        
        if api_episodes.empty? && cached_episodes.present?
          api_episodes = cached_episodes.map(&:to_api_hash)
        end
      end
      
      # Fetch local episode discussions
      local_discussions = AnimeDatabase::AnimeEpisodeTopic
        .for_anime(anime_id)
        .includes(:topic)
        .to_a
        .index_by(&:episode_number)

      # Merge API data with local discussions
      merged_episodes = api_episodes.map.with_index do |ep, index|
        # Use 'mal_id' as episode number, fallback to index+1 if mal_id is missing or suspicious
        # In Jikan v4 episodes, mal_id IS the episode number.
        ep_num = (ep["mal_id"] || ep["episode"] || (index + 1)).to_i
        local_et = local_discussions[ep_num]

        {
          episode_number: ep_num,
          title: ep["title"] || "Episode #{ep_num}",
          title_japanese: ep["title_japanese"],
          duration: ep["duration"],
          aired_at: ep["aired"] || local_et&.aired_at,
          filler: ep["filler"] || false,
          recap: ep["recap"] || false,
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

      render json: { episodes: merged_episodes, streaming: jikan_streaming }
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
                    "anime_seasons_v2_#{year}_#{season}"
                  else
                    "anime_seasons_now_v4"
                  end

      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        url = if year.present? && season.present?
                "https://api.jikan.moe/v4/seasons/#{year}/#{season}"
              else
                "https://api.jikan.moe/v4/seasons/now"
              end
        res = fetch_from_api(url)
        if res.is_a?(Hash) && res["data"].present?
          res["data"].each do |a|
            a["slug"] ||= a["title"].to_s.parameterize
            a["is_numeric_id"] = true
          end
        end
        res
      end

      if response.is_a?(Hash) && response["data"].present?
        response["data"].each do |a|
          title = a["title"] || a["title_english"] || a["title_japanese"]
          a["slug"] = title.to_s.parameterize if a["slug"].blank? && title.present?
          a["is_numeric_id"] = true if a["is_numeric_id"].nil?
        end
        merge_local_images(response["data"])
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
      # Fetch watchlist entries
      results = DB.query(<<~SQL, user.id)
        SELECT * FROM anime_watchlists 
        WHERE user_id = ? 
        ORDER BY updated_at DESC
      SQL

      # Fetch cache info for these anime to get accurate total episodes and types
      anime_ids = results.map { |r| r.anime_id.to_i }.uniq.select { |id| id > 0 }
      cache_map = {}
      
      if anime_ids.any?
        ids_string = anime_ids.join(",")
        cache_results = DB.query("SELECT mal_id, episodes_total FROM anime_cache WHERE mal_id IN (#{ids_string})")
        
        cache_results.each do |row|
          cache_map[row.mal_id.to_s] = row
        end
      end

      # Build the response data
      response_data = results.map { |row|
        cache_entry = cache_map[row.anime_id.to_s]
        
        # Safe column access in case migrations haven't run or columns are missing
        w_watched = row.respond_to?(:episodes_watched) ? row.episodes_watched.to_i : 0
        w_total = row.respond_to?(:total_episodes) ? row.total_episodes.to_i : 0
        c_total = cache_entry ? cache_entry.episodes_total.to_i : 0
        
        # Determine total episodes: favor watchlist, fall back to cache
        display_total = w_total > 0 ? w_total : c_total

        title = row.title || (cache_entry ? "Anime" : "Unknown")
        
        {
          anime_id: row.anime_id,
          slug: (title || row.title).to_s.parameterize,
          status: row.status,
          title: title,
          image_url: row.image_url,
          type: "TV",
          episodes_watched: w_watched,
          total_episodes: display_total > 0 ? display_total : nil
        }
      }
      
      # Queue background job to fill in missing episode counts (non-blocking)
      missing_ids = response_data.select { |item| item[:total_episodes].nil? }.map { |item| item[:anime_id] }
      if missing_ids.any?
        Jobs.enqueue(:watchlist_sync_job, anime_ids: missing_ids.first(10))
      end
      
      merge_local_images(response_data)
      render json: { data: response_data }
    end

    def update_watchlist
      return render json: { error: "Not logged in" }, status: 403 unless current_user
      return render json: { error: "Insufficient permissions" }, status: 403 unless current_user.trust_level >= SiteSetting.anime_min_trust_level
      
      anime_id = params[:anime_id].to_s
      status = params[:status]
      title = params[:title]
      image_url = params[:image_url]
      episodes_watched = params[:episodes_watched].to_i
      total_episodes = params[:total_episodes].to_i
      
      # If total_episodes is 0, try to fetch from cache
      if total_episodes == 0
        cache_entry = DB.query_single("SELECT episodes_total FROM anime_cache WHERE mal_id = ?", anime_id.to_i).first
        total_episodes = cache_entry.to_i if cache_entry
      end

      # Validate status enum
      # ...
      valid_statuses = %w[watching completed planned plan_to_watch on_hold dropped]
      unless valid_statuses.include?(status)
        return render json: { error: "Invalid status. Must be: #{valid_statuses.join(', ')}" }, status: 400
      end

      DB.exec(<<~SQL, current_user.id, anime_id, status, title, image_url, episodes_watched, total_episodes, Time.now, Time.now)
        INSERT INTO anime_watchlists (user_id, anime_id, status, title, image_url, episodes_watched, total_episodes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT (user_id, anime_id)
        DO UPDATE SET 
          status = EXCLUDED.status, 
          episodes_watched = EXCLUDED.episodes_watched,
          total_episodes = CASE 
            WHEN EXCLUDED.total_episodes > 0 THEN EXCLUDED.total_episodes 
            ELSE anime_watchlists.total_episodes 
          END,
          updated_at = EXCLUDED.updated_at
      SQL

      render json: { success: true, status: status, episodes_watched: episodes_watched }
    end

    def remove_watchlist
      return render json: { error: "Not logged in" }, status: 403 unless current_user
      
      DB.exec("DELETE FROM anime_watchlists WHERE user_id = ? AND anime_id = ?", current_user.id, params[:anime_id].to_s)
      
      render json: { success: true }
    end

    def calendar
      source = SiteSetting.anime_calendar_source
      cache_key = "anime_calendar_v6_#{source}"
      
      response = Discourse.cache.fetch(cache_key, expires_in: SiteSetting.anime_api_cache_duration.hours) do
        case source
        when "animeschedule"
          items = AnimescheduleService.fetch_timetable
          if items.present?
            Rails.logger.info("[AnimeSchedule] Mapping #{items.length} items for calendar")
            mapped_anime = items.map do |item|
              begin
                airing_time = Time.parse(item['episodeDate'])
                
                # Construct proper image URL from production CDN
                image_url = if item['imageVersionRoute'].present?
                  "https://img.animeschedule.net/production/assets/public/img/#{item['imageVersionRoute']}"
                else
                  nil
                end
                
                {
                  "mal_id" => item['route'], # Use route as ID (not numeric!)
                  "is_numeric_id" => false, # Flag to disable detail page links
                  "title" => item['english'] || item['romaji'] || item['title'],
                  "images" => {
                    "jpg" => { 
                      "large_image_url" => image_url,
                      "image_url" => image_url
                    }
                  },
                  "episode" => item['episodeNumber'],
                  "episodes" => item['episodes'],
                  "status" => item['status'],
                  "broadcast" => {
                    "day" => airing_time.strftime("%A"),
                    "time" => airing_time.strftime("%H:%M"),
                    "timezone" => airing_time.zone
                  },
                  "airing_at" => airing_time.to_i
                }
              rescue => e
                Rails.logger.warn("[AnimeSchedule] Error mapping item #{item['title']}: #{e.message}")
                next
              end
            end.compact
            Rails.logger.info("[AnimeSchedule] Successfully mapped #{mapped_anime.length} items")
            { "data" => mapped_anime }
          else
            nil
          end
        when "jikan"
          jikan_response = fetch_from_api("https://api.jikan.moe/v4/schedules?limit=50")
          if jikan_response.is_a?(Hash) && jikan_response["data"].present?
            jikan_response["data"].each { |item| item["is_numeric_id"] = true }
          end
          jikan_response
        else # anilist or default
          anilist_items = AnilistService.fetch_airing_schedule(7)
          
          if anilist_items.present?
            mapped_anime = anilist_items.map do |item|
              media = item['media']
              next if media['idMal'].blank?

              airing_time = Time.at(item['airingAt']).in_time_zone("Tokyo")
              
              {
                "mal_id" => media['idMal'],
                "is_numeric_id" => true,
                "slug" => (media['title']['english'] || media['title']['romaji']).to_s.parameterize,
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
                "airing_at" => item['airingAt']
              }
            end.compact

            mapped_anime = mapped_anime.uniq { |a| a['mal_id'] }
            mapped_anime.sort_by! { |a| -(a['members'] || 0) }
            
            { "data" => mapped_anime }
          else
            # Jikan fallback also needs slugs
            res = fetch_from_api("https://api.jikan.moe/v4/schedules?limit=25")
            if res.is_a?(Hash) && res["data"].present?
              res["data"].each do |a| 
                a["slug"] = a["title"].to_s.parameterize
                a["is_numeric_id"] = true
              end
            end
            res
          end
        end
      end

      if response.is_a?(Hash) && response["data"].present?
        response["data"].each do |a|
          a["slug"] ||= (a["title"] || a["title_english"] || a["title_japanese"]).to_s.parameterize if a["slug"].blank?
        end
        merge_local_images(response["data"])
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

    def map_anilist_to_internal(media)
      title = media.dig('title', 'english') || media.dig('title', 'romaji')
      slug = title.to_s.parameterize
      
      {
        "mal_id" => media['idMal'] || "al-#{media['id']}",
        "anilist_id" => media['id'],
        "slug" => slug,
        "title" => title,
        "images" => {
          "jpg" => {
            "large_image_url" => media.dig('coverImage', 'large'),
            "image_url" => media.dig('coverImage', 'medium')
          }
        },
        "streaming" => (media['externalLinks'] || []).select { |l| 
          ["Netflix", "Crunchyroll", "Hulu", "Disney Plus", "Amazon", "Funimation", "HIDIVE"].include?(l['site'])
        }.map { |l| { "name" => l['site'], "url" => l['url'] } },
        "banner_image" => media['bannerImage'],
        "score" => media['averageScore'] ? (media['averageScore'].to_f / 10).round(2) : nil,
        "popularity" => media['popularity'],
        "synopsis" => media['description'],
        "episodes" => media['episodes'],
        "status" => media['status'],
        "genres" => (media['genres'] || []).map { |g| { "name" => g } },
        "studios" => (media.dig('studios', 'nodes') || []).map { |s| { "name" => s['name'] } },
        "source" => media['source'],
        "trailer" => if media['trailer'] && media.dig('trailer', 'site') == 'youtube'
          {
            "youtube_id" => media.dig('trailer', 'id'),
            "url" => "https://www.youtube.com/watch?v=#{media.dig('trailer', 'id')}",
            "embed_url" => "https://www.youtube-nocookie.com/embed/#{media.dig('trailer', 'id')}"
          }
        else
          nil
        end,
        "is_numeric_id" => media['idMal'].present?,
        "aired" => {
          "from" => media.dig('startDate', 'year') ? Date.new(media.dig('startDate', 'year'), media.dig('startDate', 'month') || 1, media.dig('startDate', 'day') || 1).iso8601 : nil,
          "to" => media.dig('endDate', 'year') ? Date.new(media.dig('endDate', 'year'), media.dig('endDate', 'month') || 1, media.dig('endDate', 'day') || 1).iso8601 : nil,
          "string" => format_anilist_date(media['startDate'], media['endDate'])
        },
        "anilist" => {
          "id" => media["id"],
          "url" => media["siteUrl"],
          "characters" => media.dig("characters", "nodes"),
          "relations" => media.dig("relations", "edges"),
          "external_links" => media["externalLinks"],
          "streaming" => media["streamingEpisodes"]
        }
      }
    end

    def format_anilist_date(start, _end)
      return "N/A" unless start && start['year']
      
      month_names = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
      month = month_names[start['month'] || 0]
      day = start['day']
      year = start['year']
      
      if day && start['month']
        "#{month} #{day}, #{year}"
      elsif start['month']
        "#{month} #{year}"
      else
        year.to_s
      end
    end

    def resolve_params_id(id)
      return id if id.blank?
      return id if id =~ /\A\d+\z/ || id =~ /\Aal-\d+\z/

      # 0. Try local cache first (highly recommended for performance and consistency)
      begin
        cached = nil
        if AnimeDatabase::AnimeCache.column_names.include?("slug")
          cached = AnimeDatabase::AnimeCache.find_by(slug: id)
        end
        
        # Fallback to title matching if slug not found or column missing
        # We strip non-alphanumeric to be more robust (Solo Leveling -> sololeveling)
        clean_id = id.downcase.gsub(/[^a-z0-9]/, '')
        cached ||= AnimeDatabase::AnimeCache.all.find { |a| 
          (a.title || "").downcase.gsub(/[^a-z0-9]/, '') == clean_id ||
          (a.title_english || "").downcase.gsub(/[^a-z0-9]/, '') == clean_id
        }
        
        if cached
          Rails.logger.debug("[Anime Plugin] Resolved slug '#{id}' from local cache to ID: #{cached.mal_id}")
          return cached.mal_id.to_s
        end
      rescue => e
        Rails.logger.warn("[Anime Plugin] Local cache resolution failed for '#{id}': #{e.message}")
      end

      # Handle slugs by searching AniList/AnimeSchedule
      Rails.logger.info("[Anime Plugin] Resolving slug: #{id}")
      
      # Try AniList first
      search_query = id.gsub('-', ' ')
      anilist_results = []
      begin
        anilist_results = AnilistService.search(search_query)
      rescue => e
        Rails.logger.error("[Anime Plugin] AniList search error during resolution: #{e.message}")
      end
      
      match = nil
      if anilist_results.present?
        match = anilist_results.find { |a| 
          english_title = a.dig('title', 'english')
          romaji_title = a.dig('title', 'romaji')
          (english_title.present? && english_title.parameterize == id) || 
          (romaji_title.present? && romaji_title.parameterize == id)
        }
        
        match ||= anilist_results.first
      end
      
      if match
        resolved_id = match['idMal'] || "al-#{match['id']}"
        Rails.logger.info("[Anime Plugin] Resolved slug '#{id}' to ID: #{resolved_id}")
        return resolved_id.to_s
      end

      # Fallback to AnimeSchedule
      begin
        as_data = AnimescheduleService.fetch_anime_details(id)
        if as_data && as_data["websites"] && as_data["websites"]["mal"]
          mal_url = as_data["websites"]["mal"]
          if mal_url =~ /anime\/(\d+)/
            resolved_id = $1
            Rails.logger.info("[Anime Plugin] Resolved slug '#{id}' via AnimeSchedule to ID: #{resolved_id}")
            return resolved_id.to_s
          end
        end
      rescue => e
        Rails.logger.error("[Anime Plugin] AnimeSchedule resolution error: #{e.message}")
      end
      
      Rails.logger.warn("[Anime Plugin] Could not resolve slug: #{id}")
      id # Return original if everything fails
    end

    def merge_local_images(data)
      return data if data.blank?
      
      items = data.is_a?(Array) ? data : [data]
      mal_ids = items.map { |a| a["mal_id"].to_i }.select { |id| id > 0 }.uniq
      return data if mal_ids.empty?
      
      # Batch fetch local images
      cache_data = DB.query("SELECT mal_id, local_image_url FROM anime_cache WHERE mal_id IN (#{mal_ids.join(',')}) AND local_image_url IS NOT NULL")
      image_map = cache_data.each_with_object({}) { |r, h| h[r.mal_id.to_i] = r.local_image_url }
      
      return data if image_map.empty?
      
      items.each do |item|
        # Skip if mal_id is not present or an al- prefix (AniList internal)
        next if item["mal_id"].blank? || item["mal_id"].to_s.start_with?("al-")
        
        mid = item["mal_id"].to_i
        if mid > 0 && image_map[mid]
          url = image_map[mid]
          # Ensure absolute URL if it's a relative path
          url = "#{Discourse.base_url}#{url}" if url.start_with?("/")
          
          if item["images"] && item["images"]["jpg"]
            item["images"]["jpg"]["large_image_url"] = url
            item["images"]["jpg"]["image_url"] = url
            Rails.logger.debug("[Anime Plugin] Merged local image for #{mid}: #{url}")
          end
          # Also check for flat image_url (watchlist)
          item["image_url"] = url if item.key?("image_url")
        end
      end
      
      data
    end

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
