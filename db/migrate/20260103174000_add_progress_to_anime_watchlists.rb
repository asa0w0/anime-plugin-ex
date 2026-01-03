class AddProgressToAnimeWatchlists < ActiveRecord::Migration[7.0]
  def change
    add_column :anime_watchlists, :episodes_watched, :integer, default: 0, null: false
    add_column :anime_watchlists, :total_episodes, :integer, default: 0, null: false
  end
end
