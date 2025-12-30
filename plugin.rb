# name: discourse-anime-database
# about: A Discourse plugin to create an anime database with list and detail views.
# version: 0.1
# authors: Antigravity
# url: https://github.com/yourusername/discourse-anime-database

enabled_site_setting :anime_database_enabled

register_asset "stylesheets/common/anime-database.scss"
register_svg_icon "comments"
register_svg_icon "plus"

after_initialize do
  register_topic_custom_field_type("anime_mal_id", :string)

  module ::AnimeDatabase
    class Engine < ::Rails::Engine
      engine_name "anime_database"
      isolate_namespace AnimeDatabase
    end
  end

  load File.expand_path("../app/controllers/anime_database/anime_controller.rb", __FILE__)

  AnimeDatabase::Engine.routes.draw do
    get "/list" => "anime#index"
    get "/details/:id" => "anime#show"
  end

  Discourse::Application.routes.append do
    mount ::AnimeDatabase::Engine, at: "/anime-api"
  end
end
