require 'net/http'
require 'json'

def fetch_anilist(mal_id)
  query = <<~GRAPHQL
    query ($malId: Int) {
      Media(idMal: $malId, type: ANIME) {
        streamingEpisodes {
          title
          site
        }
      }
    }
  GRAPHQL

  uri = URI('https://graphql.anilist.co')
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    query: query,
    variables: { malId: mal_id.to_i }
  }.to_json

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  JSON.parse(response.body)
end

data = fetch_anilist(11061)
episodes = data.dig('data', 'Media', 'streamingEpisodes')

# Count occurrences of episodes
counts = Hash.new(0)
episodes.each { |ep| counts[ep['title']] += 1 }

# Find episodes with multiple providers
duplicates = counts.select { |k, v| v > 1 }

puts "Total Episodes in data: #{episodes.length}"
puts "Episodes with multiple providers: #{duplicates.keys.join(', ')}"
puts "\nFull provider list for first 5 episodes:"
episodes.first(10).each { |ep| puts "#{ep['title']}: #{ep['site']}" }
