# frozen_string_literal: true

class CreateAnimeEpisodeTopics < ActiveRecord::Migration[7.0]
  def up
    return if table_exists?(:anime_episode_topics)
    
    create_table :anime_episode_topics do |t|
      t.string :anime_id, null: false, limit: 255
      t.integer :episode_number, null: false
      t.integer :topic_id, null: false
      t.datetime :aired_at
      t.timestamps null: false
    end
    
    add_index :anime_episode_topics, [:anime_id, :episode_number], unique: true, name: 'idx_anime_ep_topics_anime_ep'
    add_index :anime_episode_topics, :topic_id, name: 'idx_anime_ep_topics_topic_id'
  end
  
  def down
    drop_table :anime_episode_topics if table_exists?(:anime_episode_topics)
  end
end
