# frozen_string_literal: true

class CreateAnimeEpisodesCache < ActiveRecord::Migration[7.0]
  def change
    create_table :anime_episodes_cache do |t|
      t.integer :mal_id, null: false
      t.integer :episode_number, null: false
      t.string :title
      t.string :title_japanese
      t.string :title_romanji
      t.datetime :aired_at
      t.integer :duration_seconds
      t.boolean :filler, default: false
      t.boolean :recap, default: false
      t.text :synopsis
      
      t.timestamps
    end

    add_index :anime_episodes_cache, [:mal_id, :episode_number], unique: true, name: 'idx_episodes_cache_mal_ep'
    add_index :anime_episodes_cache, :mal_id
    add_index :anime_episodes_cache, :aired_at
  end
end
