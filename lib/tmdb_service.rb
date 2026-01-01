# frozen_string_literal: true

require 'net/http'
require 'json'

class TmdbService
  BASE_URL = 'https://api.themoviedb.org/3'
  CACHE_DURATION = 7.days
  ANIME_GENRE_ID = 16 # Animation

  def self.search_anime(title)
    return nil unless SiteSetting.anime_enable_tmdb
    return nil if SiteSetting.anime_tmdb_api_key.blank?
    return nil if title.blank?

    cache_key = "tmdb_search_#{Digest::MD5.hexdigest(title.downcase)}"
    
    Discourse.cache.fetch(cache_key, expires_in: CACHE_DURATION) do
      execute_search(title)
    end
  rescue => e
    Rails.logger.error("TMDB API error searching '#{title}': #{e.message}")
    nil
  end

  def self.fetch_details(tmdb_id)
    return nil unless SiteSetting.anime_enable_tmdb
    return nil if SiteSetting.anime_tmdb_api_key.blank?
    return nil if tmdb_id.blank?

    cache_key = "tmdb_tv_#{tmdb_id}"
    
    Discourse.cache.fetch(cache_key, expires_in: CACHE_DURATION) do
      execute_details(tmdb_id)
    end
  rescue => e
    Rails.logger.error("TMDB API error for ID #{tmdb_id}: #{e.message}")
    nil
  end

  private

  def self.execute_search(title)
    params = {
      api_key: SiteSetting.anime_tmdb_api_key,
      query: title,
      with_genres: ANIME_GENRE_ID,
      include_adult: false
    }

    uri = URI("#{BASE_URL}/search/tv")
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.code == '200'
      data = JSON.parse(response.body)
      results = data['results'] || []
      
      # Return first match (usually most relevant)
      results.first
    else
      Rails.logger.error("TMDB search returned #{response.code}: #{response.body}")
      nil
    end
  end

  def self.execute_details(tmdb_id)
    params = {
      api_key: SiteSetting.anime_tmdb_api_key,
      append_to_response: 'credits,videos,images,content_ratings'
    }

    uri = URI("#{BASE_URL}/tv/#{tmdb_id}")
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error("TMDB details returned #{response.code}: #{response.body}")
      nil
    end
  end
end
