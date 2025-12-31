# name: anime-plugin-ex
# about: A Discourse plugin to create an anime database with list and detail views.
# version: 0.1
# authors: Antigravity
# url: https://github.com/yourusername/discourse-anime-database

enabled_site_setting :anime_database_enabled

register_asset "stylesheets/common/anime-database.scss"
register_svg_icon "comments"
register_svg_icon "comment"
register_svg_icon "far-comment"
register_svg_icon "far-comment-dots"
register_svg_icon "plus"
register_svg_icon "film"
register_svg_icon "trash-alt"
register_svg_icon "calendar-alt"
register_svg_icon "play-circle"
register_svg_icon "check-circle"
register_svg_icon "clock"
register_svg_icon "pause-circle"
register_svg_icon "times-circle"
register_svg_icon "sync"

after_initialize do
  register_topic_custom_field_type("anime_mal_id", :string)

  add_to_serializer(:topic_view, :anime_mal_id) { object.topic.custom_fields["anime_mal_id"] }

  add_permitted_post_create_param(:anime_mal_id)

  DiscourseEvent.on(:post_created) do |post, opts, user|
    if post.is_first_post? && opts[:anime_mal_id].present?
      topic = post.topic
      topic.custom_fields["anime_mal_id"] = opts[:anime_mal_id]
      topic.save_custom_fields
      Rails.logger.info("Anime Plugin: Saved anime_mal_id=#{opts[:anime_mal_id]} to topic #{topic.id}")
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
    get "/calendar" => "anime#calendar"
    get "/seasons" => "anime#seasons"
    get "/seasons/:year/:season" => "anime#seasons"
    get "/:id" => "anime#show"
  end

  Discourse::Application.routes.append do
    mount ::AnimeDatabase::Engine, at: "/anime"
    get "/u/:username/watchlist" => "users#show", constraints: { username: RouteFormat.username }
  end
end
