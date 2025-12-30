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
      
      # Find or suggest a topic for comments (not cached to stay accurate)
      topic = ::TopicCustomField.where(name: "anime_mal_id", value: id.to_s).first&.topic
      if topic
        response = response.dup
        response["topic_id"] = topic.id
        response["topic_slug"] = topic.slug
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
