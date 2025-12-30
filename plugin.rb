# name: anime-plugin-ex
# about: A Discourse plugin to create an anime database with list and detail views.
# version: 0.1
# authors: Antigravity
# url: https://github.com/yourusername/discourse-anime-database

enabled_site_setting :anime_database_enabled

register_asset "stylesheets/common/anime-database.scss"
register_svg_icon "comments"
register_svg_icon "plus"
register_svg_icon "trash-alt"

after_initialize do
  register_topic_custom_field_type("anime_mal_id", :string)
  register_topic_custom_field_type("anime_episode_number", :string)

  add_to_serializer(:topic_view, :anime_mal_id) { object.topic.custom_fields["anime_mal_id"] }
  add_to_serializer(:topic_view, :anime_episode_number) { object.topic.custom_fields["anime_episode_number"] }

  add_permitted_post_create_param(:anime_mal_id)
  add_permitted_post_create_param(:anime_episode_number)

  DiscourseEvent.on(:post_created) do |post, opts, user|
    if opts[:anime_mal_id].present?
      topic = post.topic
      topic.custom_fields["anime_mal_id"] = opts[:anime_mal_id]
      topic.custom_fields["anime_episode_number"] = opts[:anime_episode_number] if opts[:anime_episode_number].present?
      topic.save_custom_fields
      Rails.logger.info("Anime Plugin: Saved anime_mal_id=#{opts[:anime_mal_id]} and episode=#{opts[:anime_episode_number]} to topic #{topic.id}")
    end
  end

  require_relative "app/controllers/anime_database/anime_controller"

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
    get "/:id" => "anime#show"
  end

  Discourse::Application.routes.append do
    mount ::AnimeDatabase::Engine, at: "/anime"
    get "/u/:username/watchlist" => "users#show", constraints: { username: RouteFormat.username }
  end
end
