require 'rubygems'
gem 'google-api-client', '>0.7'

require 'fileutils'
require 'json'
require 'yaml'

require_relative 'lib/helper'
require_relative 'lib/youtube'

APPLICATION_NAME = 'YouTube Data Migration'.freeze

READ_SCOPE = Google::Apis::YoutubeV3::AUTH_YOUTUBE_READONLY
WRITE_SCOPE = Google::Apis::YoutubeV3::AUTH_YOUTUBE

old_service = Google::Apis::YoutubeV3::YouTubeService.new
old_service.client_options.application_name = APPLICATION_NAME
old_service.authorization = authorize 'read data from old account', './auth/old_account_client_secret.json',
                                      './.credentials/old-account-credentials.yaml', READ_SCOPE

new_service = Google::Apis::YoutubeV3::YouTubeService.new
new_service.client_options.application_name = APPLICATION_NAME
new_service.authorization = authorize 'manage your new account', './auth/new_account_client_secret.json',
                                      './.credentials/new-account-credentials.yaml', WRITE_SCOPE

# Read Old Account

SUBCRIBED_CHANNELS = './data/old-subscribed-channels.yaml'.freeze
PLAYLISTS = './data/old-playlists.yaml'.freeze

if File.exist? SUBCRIBED_CHANNELS
  puts 'Loading subscribed channels from file'
  my_subscribed_channels = YAML.load File.read SUBCRIBED_CHANNELS
else
  puts 'Getting subscribed channels'
  my_subscribed_channels = subscribed_channels_from old_service
  File.write SUBCRIBED_CHANNELS, YAML.dump(my_subscribed_channels)
end

if File.exist? PLAYLISTS
  puts 'Loading playlists from file'
  my_old_playlists = YAML.load File.read PLAYLISTS
else
  puts 'Getting playlists'
  my_old_playlists = personal_playlists_from old_service
  File.write PLAYLISTS, YAML.dump(my_old_playlists)
end

# Manage New Account

already_subscribed_channels = subscribed_channels_from new_service
current_playlists = personal_playlists_from new_service

my_subscribed_channels.each do |to_subscribe|
  next if already_subscribed_channels.any? { |ch| ch[:id] == to_subscribe[:id] } || !confirm?("Subscribe to '#{to_subscribe[:name]}'")
  response = new_service.insert_subscription 'snippet', subscription(to_subscribe[:id])
  $stderr.puts 'Failed!' unless response.snippet.resource_id.channel_id == to_subscribe[:id]
rescue Google::Apis::ClientError => e
  $stderr.puts "Failed to subscribe to '#{to_subscribe[:name]}': #{e}"
end

my_old_playlists.each do |pl_to_create|
  next if current_playlists.any? { |pl| pl[:name] == pl_to_create[:name] } || !confirm?("Create a new playlist '#{pl_to_create[:name]}'")
  playlist = new_service.insert_playlist 'snippet,status', playlist(pl_to_create[:name], pl_to_create[:description])
  current_playlists << { id: playlist.id, name: playlist.snippet.title, description: playlist.snippet.description, video_ids: [] }
rescue Google::Apis::ClientError => e
  $stderr.puts "Failed to create playlist '#{pl_to_create[:name]}': #{e}"
end

my_old_playlists.each do |source_pl|
  current_pl = current_playlists.find { |pl| pl[:name] == source_pl[:name] }
  videos_to_add = source_pl[:video_ids] - current_pl[:video_ids]
  next if videos_to_add.empty? || !confirm?("Adding #{videos_to_add.size} missing videos to playlist '#{current_pl[:name]}'")
  errors = videos_to_add.each_with_object([]) do |video_id, errs|
    added_item = new_service.insert_playlist_item 'snippet', playlist_item(current_pl[:id], video_id)
    print '.'
    current_pl[:video_ids] << added_item.snippet.resource_id.video_id if added_item
  rescue Google::Apis::ClientError => e
    print 'x'
    errs << e.message
  end
  puts
  puts "Failed to add some videos with errors: #{errors}" unless errors.empty?
end

puts 'Done!'
