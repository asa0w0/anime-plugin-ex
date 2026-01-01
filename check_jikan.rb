require 'net/http'
require 'json'

def fetch_jikan(mal_id)
  uri = URI("https://api.jikan.moe/v4/anime/#{mal_id}/full")
  response = Net::HTTP.get(uri)
  JSON.parse(response)
end

data = fetch_jikan(11061)
streaming = data.dig('data', 'streaming')

puts "Streaming services from Jikan:"
if streaming
  streaming.each do |s|
    puts "- #{s['name']}: #{s['url']}"
  end
else
  puts "No streaming data found in Jikan."
end
