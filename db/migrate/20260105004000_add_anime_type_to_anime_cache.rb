# frozen_string_literal: true

class AddAnimeTypeToAnimeCache < ActiveRecord::Migration[7.0]
  def change
    add_column :anime_cache, :anime_type, :string
    add_index :anime_cache, :anime_type
  end
end
