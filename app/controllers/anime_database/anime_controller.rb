require_dependency "application_controller"

module AnimeDatabase
  class AnimeController < ::ApplicationController
    requires_plugin "anime-plugin-ex"

    def index
      url = "https://api.jikan.moe/v4/top/anime"
      if params[:q].present?
        url = "https://api.jikan.moe/v4/anime?q=#{CGI.escape(params[:q])}"
      end
      
      response = fetch_from_api(url)
      render json: response
    end

    def show
      id = params[:id]
      url = "https://api.jikan.moe/v4/anime/#{id}/full"
      
      response = fetch_from_api(url)
      
      # Find or suggest a topic for comments
      topic = ::TopicCustomField.where(name: "anime_mal_id", value: id.to_s).first&.topic
      if topic
        response[:topic_id] = topic.id
        response[:topic_slug] = topic.slug
      end

      render json: response
    end

    private

    def fetch_from_api(url)
      # In a real Discourse plugin, you'd use Discourse.cache to cache these responses
      # and FinalDestination to safely fetch.
      # For now, we'll do a simple fetch.
      
      begin
        conn = Excon.new(url, expects: [200, 404])
        resp = conn.get
        JSON.parse(resp.body)
      rescue => e
        { error: e.message }
      end
    end
  end
end
