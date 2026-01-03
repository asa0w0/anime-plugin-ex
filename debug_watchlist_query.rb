
# Script to test the watchlist query and find the cause of the 500 error
require File.expand_path("../../config/environment", __FILE__)

def test_watchlist_query
  user = User.first # Assuming there's at least one user
  if !user
    puts "No user found to test with."
    return
  end
  
  puts "Testing query for user: #{user.username} (ID: #{user.id})"
  
  begin
    query = <<~SQL
      SELECT w.*, c.episodes_total as cache_episodes_total, c.type as cache_type
      FROM anime_watchlists w
      LEFT JOIN anime_cache c ON c.mal_id = CAST(NULLIF(w.anime_id, '') AS INTEGER)
      WHERE w.user_id = #{user.id}
      ORDER BY w.updated_at DESC
    SQL
    
    puts "Running query..."
    result = DB.query(query)
    puts "Query successful! Found #{result.length} rows."
    
    result.each_with_index do |row, i|
      puts "Row #{i}: ID=#{row.anime_id}, Title=#{row.title}, CacheTotal=#{row.cache_episodes_total rescue 'N/A'}"
    end
    
  rescue => e
    puts "Query FAILED!"
    puts "Error: #{e.message}"
    puts e.backtrace.first(10)
  end
end

test_watchlist_query
