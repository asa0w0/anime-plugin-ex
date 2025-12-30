# name: anime-plugin-ex
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
  add_permitted_post_create_param(:anime_mal_id)

  on(:topic_created) do |topic, opts, user|
    if opts[:anime_mal_id].present?
      topic.custom_fields["anime_mal_id"] = opts[:anime_mal_id]
      topic.save_custom_fields
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
    get "/:id" => "anime#show"
  end

  Discourse::Application.routes.append do
    mount ::AnimeDatabase::Engine, at: "/anime"
  end
end
