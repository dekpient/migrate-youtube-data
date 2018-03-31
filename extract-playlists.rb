require 'json'
require 'yaml'

def nested_hash_value(obj, key, &block)
  if obj.respond_to?(:key?) && obj.key?(key)
    yield obj[key]
  elsif obj.respond_to?(:each)
    obj.find_all { |*a| nested_hash_value(a.last, key, &block) }
  end
end

def extract_initial_data(file)
  initial_data = File.readlines(file, chomp: true).find { |line| line.include? 'window["ytInitialData"] = {' }.strip.chomp(';')
  initial_data.slice!(0, 'window["ytInitialData"] = '.size)
  initial_data
end

def extract_playlist_data(pl)
  {
    channel_name: pl['longBylineText']['runs'][0]['text'],
    channel_id: pl['longBylineText']['runs'][0]['navigationEndpoint']['browseEndpoint']['browseId'],
    id: pl['playlistId'],
    name: pl['title']['simpleText']
  }
end

saved_playlists = Dir.glob(['./data/more-saved-playlists*.json', './data/saved-playlists.html']).each_with_object([]) do |file, playlists|
  raw_content = File.extname(file) == '.html' ? extract_initial_data(file) : File.read(file)
  data = JSON.parse raw_content
  nested_hash_value(data, 'gridPlaylistRenderer') { |item| playlists << extract_playlist_data(item) }
end

puts "You have #{saved_playlists.uniq.count} saved playlist(s)"
File.write './data/saved-playlists.yaml', YAML.dump(saved_playlists)
