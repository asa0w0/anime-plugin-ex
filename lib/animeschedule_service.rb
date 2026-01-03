# frozen_string_literal: true

require 'net/http'
require 'json'

class AnimescheduleService
  ENDPOINT = 'https://animeschedule.net/api/v3'
  
  def self.fetch_timetable(air_type = 'sub')
    api_key = SiteSetting.anime_animeschedule_api_key
    return nil if api_key.blank?

    # AnimeSchedule.net API v3 /timetables/{airType}
    uri = URI("#{ENDPOINT}/timetables/#{air_type}")
    params = { tz: "Asia/Tokyo" } # Use Tokyo for consistency with mapping
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Accept'] = 'application/json'

    response = http.request(request)

    if response.code == '200'
      data = JSON.parse(response.body)
      Rails.logger.info("[AnimeSchedule] Successfully fetched #{data.is_a?(Array) ? data.length : 'unknown'} items")
      data
    else
      Rails.logger.warn("[AnimeSchedule] API returned #{response.code}: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("[AnimeSchedule] Error fetching timetable: #{e.message}")
    nil
  end
end
