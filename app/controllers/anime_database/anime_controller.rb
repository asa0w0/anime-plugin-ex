require_dependency "application_controller"

module AnimeDatabase
  class AnimeController < ::ApplicationController
    requires_plugin "anime-plugin-ex"

    def index
      cache_key = "anime_list_#{params[:q] || 'top'}"
      
      response = Discourse.cache.fetch(cache_key, expires_in: 1.hour) do
        url = "https://api.jikan.moe/v4/top/anime"
        if params[:q].present?
          url = "https://api.jikan.moe/v4/anime?q=#{CGI.escape(params[:q])}"
        end
        fetch_from_api(url)
      end

      render json: response
    end

    def show
      id = params[:id]
      cache_key = "anime_details_#{id}"

      response = Discourse.cache.fetch(cache_key, expires_in: 24.hours) do
        url = "https://api.jikan.moe/v4/anime/#{id}/full"
        fetch_from_api(url)
      end
      
      # Find all topics associated with this anime
      topics = ::TopicCustomField.where(name: "anime_mal_id", value: id.to_s)
                                 .includes(:topic)
                                 .map(&:topic)
                                 .compact
                                 .reject(&:trash?)
      
      response = response.dup
      response["topics"] = topics.map do |t|
        {
          id: t.id,
          title: t.title,
          slug: t.slug,
          post_count: t.posts_count,
          last_posted_at: t.last_posted_at
        }
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
