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

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      results = data['results'] || []
      results.first
    else
      Rails.logger.warn("[TMDB] Search returned #{response.code} for '#{title}'")
      nil
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[TMDB] Timeout searching '#{title}': #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("[TMDB] JSON parse error: #{e.message}")
    nil
  end

  def self.execute_details(tmdb_id)
    params = {
      api_key: SiteSetting.anime_tmdb_api_key,
      append_to_response: 'credits,videos,images,content_ratings'
    }

    uri = URI("#{BASE_URL}/tv/#{tmdb_id}")
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.warn("[TMDB] Details returned #{response.code} for ID #{tmdb_id}")
      nil
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[TMDB] Timeout for ID #{tmdb_id}: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("[TMDB] JSON parse error for ID #{tmdb_id}: #{e.message}")
    nil
  end
end
