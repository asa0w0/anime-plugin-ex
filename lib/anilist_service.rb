# frozen_string_literal: true

require 'net/http'
require 'json'

class AnilistService
  ENDPOINT = 'https://graphql.anilist.co'
  CACHE_DURATION = 24.hours

  def self.fetch_by_mal_id(mal_id)
    return nil unless SiteSetting.anime_enable_anilist
    return nil if mal_id.blank?

    cache_key = "anilist_mal_#{mal_id}"
    
    Discourse.cache.fetch(cache_key, expires_in: CACHE_DURATION) do
      execute_query({ malId: mal_id.to_i })
    end
  rescue => e
    Rails.logger.error("AniList API error for MAL ID #{mal_id}: #{e.message}")
    nil
  end

  def self.fetch_by_id(anilist_id)
    return nil unless SiteSetting.anime_enable_anilist
    return nil if anilist_id.blank?

    cache_key = "anilist_id_#{anilist_id}"
    
    Discourse.cache.fetch(cache_key, expires_in: CACHE_DURATION) do
      execute_query({ id: anilist_id.to_i })
    end
  rescue => e
    Rails.logger.error("AniList API error for ID #{anilist_id}: #{e.message}")
    nil
  end

  def self.search(search_query)
    return [] unless SiteSetting.anime_enable_anilist
    return [] if search_query.blank?

    query = <<~GRAPHQL
      query ($search: String) {
        Page(page: 1, perPage: 20) {
          media(search: $search, type: ANIME) {
            id
            idMal
            title {
              romaji
              english
              native
            }
            coverImage {
              large
              medium
            }
            bannerImage
            averageScore
            popularity
            description
            season
            seasonYear
            format
            status
            genres
          }
        }
      }
    GRAPHQL

    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      query: query,
      variables: { search: search_query }
    }.to_json

    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      data.dig('data', 'Page', 'media') || []
    else
      Rails.logger.warn("[AniList] Search API returned #{response.code}")
      []
    end
  rescue => e
    Rails.logger.error("[AniList] Search error: #{e.message}")
    []
  end

  def self.fetch_airing_schedule(days = 7)
    return nil unless SiteSetting.anime_enable_anilist

    start_time = Time.now.to_i
    end_time = (Time.now + days.days).to_i

    query = <<~GRAPHQL
      query ($start: Int, $end: Int) {
        Page(page: 1, perPage: 50) {
          airingSchedules(airingAt_greater: $start, airingAt_less: $end, sort: TIME_DESC) {
            airingAt
            episode
            media {
              id
              idMal
              title {
                romaji
                english
              }
              coverImage {
                large
              }
              popularity
              averageScore
              genres
              description
              status
            }
          }
        }
      }
    GRAPHQL

    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      query: query,
      variables: { start: start_time, end: end_time }
    }.to_json

    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      data.dig('data', 'Page', 'airingSchedules') || []
    else
      Rails.logger.warn("[AniList] Schedule API returned #{response.code}")
      nil
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[AniList] Timeout fetching schedule: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("[AniList] JSON parse error: #{e.message}")
    nil
  rescue => e
    Rails.logger.error("[AniList] Unexpected error: #{e.class} - #{e.message}")
    nil
  end

  private

  def self.execute_query(variables)
    query = <<~GRAPHQL
      query ($id: Int, $malId: Int) {
        Media(id: $id, idMal: $malId, type: ANIME) {
          id
          idMal
          siteUrl
          title {
            romaji
            english
            native
          }
          type
          format
          status
          description
          startDate { year month day }
          endDate { year month day }
          season
          seasonYear
          episodes
          source
          studios(isMain: true) {
            nodes {
              name
              siteUrl
            }
          }
          duration
          chapters
          volumes
          countryOfOrigin
          isAdult
          genres
          synonyms
          averageScore
          popularity
          favourites
          trending
          tags {
            name
            rank
          }
          coverImage {
            large
            medium
            color
          }
          bannerImage
          characters(page: 1, perPage: 12, sort: ROLE) {
            nodes {
              id
              name {
                full
                native
              }
              image {
                large
                medium
              }
            }
          }
          relations {
            edges {
              node {
                id
                idMal
                title {
                  romaji
                  english
                }
                type
                format
                coverImage {
                  medium
                }
              }
              relationType
            }
          }
          streamingEpisodes {
            title
            thumbnail
            url
            site
          }
          externalLinks {
            site
            url
          }
        }
      }
    GRAPHQL

    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    request.body = {
      query: query,
      variables: variables
    }.to_json

    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      data.dig('data', 'Media')
    else
      Rails.logger.warn("[AniList] API returned #{response.code} for MAL ID #{mal_id}")
      nil
    end
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[AniList] Timeout for MAL ID #{mal_id}: #{e.message}")
    nil
  rescue JSON::ParserError => e
    Rails.logger.error("[AniList] JSON parse error for MAL ID #{mal_id}: #{e.message}")
    nil
  end
end
