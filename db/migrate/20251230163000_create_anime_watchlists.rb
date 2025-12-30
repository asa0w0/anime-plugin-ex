class CreateAnimeWatchlists < ActiveRecord::Migration[7.0]
  def change
    create_table :anime_watchlists do |t|
      t.integer :user_id, null: false
      t.string :anime_id, null: false
      t.string :status, null: false, default: 'planned'
      t.string :title
      t.string :image_url
      t.timestamps
    end

    add_index :anime_watchlists, [:user_id, :anime_id], unique: true
    add_index :anime_watchlists, :user_id
  end
end
