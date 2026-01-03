#!/usr/bin/env ruby
require 'net/http'
require 'json'

API_KEY = "qqyvYNfbIqZHaoOCKeiHOohglpmfgt"
ENDPOINT = "https://animeschedule.net/api/v3"
ROUTE = "ao-no-orchestra-2nd-season" # From previous test output

uri = URI("#{ENDPOINT}/anime/#{ROUTE}")

http = Net::HTTP.new(uri.hostname, uri.port)
http.use_ssl = true

request = Net::HTTP::Get.new(uri)
request['Authorization'] = "Bearer #{API_KEY}"
request['Accept'] = 'application/json'

puts "Making request to: #{uri}"
response = http.request(request)

puts "Response Code: #{response.code}"
if response.code == '200'
  data = JSON.parse(response.body)
  puts "Parsed JSON (subset):"
  puts JSON.pretty_generate(data.slice("title", "english", "romaji", "websites"))
else
  puts "Body: #{response.body}"
end
