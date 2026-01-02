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
      execute_query(mal_id)
    end
  rescue => e
    Rails.logger.error("AniList API error for MAL ID #{mal_id}: #{e.message}")
    nil
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
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      query: query,
      variables: { start: start_time, end: end_time }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == '200'
      JSON.parse(response.body).dig('data', 'Page', 'airingSchedules')
    else
      nil
    end
  end

  private

  def self.execute_query(mal_id)
    query = <<~GRAPHQL
      query ($malId: Int) {
        Media(idMal: $malId, type: ANIME) {
          id
          siteUrl
          averageScore
          popularity
          favourites
          tags {
            name
            rank
          }
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
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/json'
    request.body = {
      query: query,
      variables: { malId: mal_id.to_i }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.code == '200'
      data = JSON.parse(response.body)
      data.dig('data', 'Media')
    else
      Rails.logger.error("AniList API returned #{response.code}: #{response.body}")
      nil
    end
  end
end
