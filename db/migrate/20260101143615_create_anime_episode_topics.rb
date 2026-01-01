# frozen_string_literal: true

class CreateAnimeEpisodeTopics < ActiveRecord::Migration[7.0]
  def change
    create_table :anime_episode_topics do |t|
      t.string :anime_id, null: false
      t.integer :episode_number, null: false
      t.integer :topic_id, null: false
      t.datetime :aired_at
      t.timestamps
    end
    
    add_index :anime_episode_topics, [:anime_id, :episode_number], unique: true, name: 'index_anime_episode_topics_on_anime_and_episode'
    add_index :anime_episode_topics, :topic_id
  end
end
