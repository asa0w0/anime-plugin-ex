# frozen_string_literal: true

class AddLocalImageToAnimeCache < ActiveRecord::Migration[7.0]
  def change
    add_column :anime_cache, :local_image_upload_id, :integer
    add_column :anime_cache, :local_image_url, :string
    add_index :anime_cache, :local_image_upload_id
  end
end
