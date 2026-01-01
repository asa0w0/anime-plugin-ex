# name: anime-plugin-ex
# about: A Discourse plugin to create an anime database with list and detail views.
# version: 0.1
# authors: Antigravity
# url: https://github.com/yourusername/discourse-anime-database

enabled_site_setting :anime_database_enabled

# API & Performance
register_asset "stylesheets/common/anime-database.scss"

# Icon registrations
register_svg_icon "comments"
register_svg_icon "comment"
register_svg_icon "far-comment"
register_svg_icon "far-comment-dots"
register_svg_icon "plus"
register_svg_icon "film"
register_svg_icon "circle-play"
register_svg_icon "circle-check"
register_svg_icon "circle-pause"
register_svg_icon "trash-can"
register_svg_icon "clock"

after_initialize do
  register_topic_custom_field_type("anime_mal_id", :string)
  register_topic_custom_field_type("anime_episode_number", :integer)

  add_to_serializer(:topic_view, :anime_mal_id) { object.topic.custom_fields["anime_mal_id"] }
  add_to_serializer(:topic_view, :anime_episode_number) { object.topic.custom_fields["anime_episode_number"] }

  add_permitted_post_create_param(:anime_mal_id)
  add_permitted_post_create_param(:anime_episode_number)

  DiscourseEvent.on(:topic_created) do |topic, opts, user|
    # Normalize opts keys to symbols for easier access
    params = opts.is_a?(Hash) ? opts.symbolize_keys : {}
    custom_fields_param = params[:topic_custom_fields] || params[:custom_fields] || {}
    custom_fields_param = custom_fields_param.symbolize_keys if custom_fields_param.is_a?(Hash)

    mal_id = params[:anime_mal_id] || custom_fields_param[:anime_mal_id]
    ep_number = params[:anime_episode_number] || custom_fields_param[:anime_episode_number]

    # Fallback to existing topic custom fields
    mal_id ||= topic.custom_fields["anime_mal_id"]
    ep_number ||= topic.custom_fields["anime_episode_number"]

    # Final fallback: Check tags ONLY if mal_id is still blank
    if mal_id.blank? && topic.tags.present?
      topic.tags.each do |tag|
        if tag.name.start_with?("anime-")
          mal_id = tag.name.sub("anime-", "")
        elsif tag.name.start_with?("episode-") && ep_number.blank?
          ep_number = tag.name.sub("episode-", "").to_i
        end
      end
    end

    if mal_id.present? && mal_id.to_s.strip != "0"
      mal_id = mal_id.to_s.strip
      Rails.logger.info("[Anime Plugin] Linking topic #{topic.id} to MAL ID #{mal_id} (Episode: #{ep_number || 'General'})")
      
      # Ensure custom fields are persistently saved on the topic
      topic.custom_fields["anime_mal_id"] = mal_id
      if ep_number.present? && ep_number.to_i > 0
        topic.custom_fields["anime_episode_number"] = ep_number.to_i
      end
      topic.save_custom_fields
      
      # If it's an episode discussion, also record it in our special table
      if ep_number.present? && ep_number.to_i > 0
        AnimeDatabase::AnimeEpisodeTopic.find_or_initialize_by(
          anime_id: mal_id,
          episode_number: ep_number.to_i
        ).tap do |et|
          et.topic_id = topic.id
          et.aired_at ||= Time.current
          et.save!
        end
        
        # Invalidate episodes list cache so the new discussion shows up immediately
        Discourse.cache.delete("anime_episodes_list_v2_#{mal_id}")
        
        Rails.logger.info("[Anime Plugin] Linked manual episode discussion: anime_id=#{mal_id} ep=#{ep_number} to topic #{topic.id}")
      else
        Rails.logger.info("[Anime Plugin] Saved general anime topic: anime_id=#{mal_id} to topic #{topic.id}")
      end
    end
  end

  require_relative "app/controllers/anime_database/anime_controller"
  require_relative "app/models/anime_episode_topic"
  require_relative "app/jobs/anime_database/anime_episode_discussion_job"

  module ::AnimeDatabase
    class Engine < ::Rails::Engine
      engine_name "anime_database"
      isolate_namespace AnimeDatabase
    end
  end

  AnimeDatabase::Engine.routes.draw do
    get "/" => "anime#index"
    get "/watchlist" => "anime#watchlist"
    get "/watchlist/:username" => "anime#watchlist"
    post "/watchlist" => "anime#update_watchlist"
    delete "/watchlist/:anime_id" => "anime#remove_watchlist"
    get "/calendar" => "anime#calendar"
    get "/seasons" => "anime#seasons"
    get "/seasons/:year/:season" => "anime#seasons"
    get "/:id/episodes" => "anime#episodes"
    post "/:anime_id/episodes/:episode_number/discussion" => "anime#create_episode_discussion"
    get "/:id" => "anime#show"
  end

  Discourse::Application.routes.append do
    mount ::AnimeDatabase::Engine, at: "/anime"
    get "/u/:username/watchlist" => "users#show", constraints: { username: RouteFormat.username }
  end
end
