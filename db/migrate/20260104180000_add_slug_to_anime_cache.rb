# frozen_string_literal: true

class AddSlugToAnimeCache < ActiveRecord::Migration[7.0]
  def change
    add_column :anime_cache, :slug, :string
    add_index :anime_cache, :slug
    
    # Also ensure external_links is present and initialized if not already
    # (Migration 20260102220000 already has it, but we can add streaming specifically)
    add_column :anime_cache, :streaming_links, :jsonb, default: []
  end
end
