# frozen_string_literal: true

class CreateAnimeCache < ActiveRecord::Migration[7.0]
  def change
    create_table :anime_cache do |t|
      t.integer :mal_id, null: false
      t.string :title, null: false
      t.string :title_english
      t.string :title_japanese
      t.text :synopsis
      t.string :image_url
      t.string :banner_url
      t.decimal :score, precision: 4, scale: 2
      t.integer :scored_by
      t.integer :rank
      t.integer :popularity
      t.integer :members
      t.integer :episodes_total
      t.string :airing_status  # "airing", "finished", "upcoming"
      t.date :aired_from
      t.date :aired_to
      t.string :season
      t.integer :year
      t.string :source  # "manga", "light_novel", etc.
      t.string :rating  # "PG-13", "R", etc.
      t.integer :duration_minutes
      t.jsonb :genres, default: []
      t.jsonb :studios, default: []
      t.jsonb :producers, default: []
      t.jsonb :themes, default: []
      t.jsonb :demographics, default: []
      t.jsonb :external_links, default: {}
      t.jsonb :raw_jikan, default: {}
      t.jsonb :raw_anilist, default: {}
      
      t.datetime :last_api_sync_at
      t.datetime :episodes_synced_at
      t.timestamps
    end

    add_index :anime_cache, :mal_id, unique: true
    add_index :anime_cache, :title
    add_index :anime_cache, :airing_status
    add_index :anime_cache, :score
    add_index :anime_cache, [:year, :season]
    add_index :anime_cache, :genres, using: :gin
  end
end
