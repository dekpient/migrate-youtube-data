require 'google/apis'
require 'google/apis/youtube_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

REDIRECT_URI = 'http://localhost'

def authorize(description, secret_file, credentials_file, scope)
  FileUtils.mkdir_p File.dirname credentials_file

  client_id = Google::Auth::ClientId.from_file secret_file
  token_store = Google::Auth::Stores::FileTokenStore.new file: credentials_file
  authorizer = Google::Auth::UserAuthorizer.new client_id, scope, token_store
  user_id = 'default'
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: REDIRECT_URI)
    puts 'Open the following URL in the browser and enter the resulting code after authorization'
    puts url
    print "To #{description}, enter the 'code' query param value from the URL: "
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code user_id: user_id, code: code, base_url: REDIRECT_URI
  end
  credentials
end

def retreive_list(service, method, part, **params)
  next_page = nil
  params = params.delete_if { |p, v| v == ''}.merge max_results: 50
  begin
    response = service.send(method, part, params.merge(page_token: next_page))
    response.items.each do |item|
      yield item
    end
    next_page = response.next_page_token
  rescue Google::Apis::ClientError => e
    binding.irb
    raise e
  end while next_page
end

def subscribed_channels_from(service)
  my_subscribed_channels = []

  retreive_list(service, :list_subscriptions, 'snippet', mine: true) do |item| # does not return suspended accounts
    my_subscribed_channels << { id: item.snippet.resource_id.channel_id, name: item.snippet.title }
  end

  my_subscribed_channels
end

def populate_playlists(service, playlists)
  playlists.each do |playlist|
    retreive_list(service, :list_playlist_items, 'snippet', playlist_id: playlist[:id]) do |item|
      raise 'WTH' unless playlist[:id] == item.snippet.playlist_id
      playlist[:video_ids] << item.snippet.resource_id.video_id
    end
  end
  playlists
end

def personal_playlists_from(service)
  my_playlists = []

  retreive_list(service, :list_playlists, 'snippet', mine: true) do |item|
    my_playlists << { id: item.id, name: item.snippet.title, description: item.snippet.description, video_ids: [] }
  end

  retreive_list(service, :list_channels, 'snippet,contentDetails', mine: true) do |item|
    # watch_history and watch_later are deprecated BOO!
    my_playlists << { id: item.content_details.related_playlists.likes, name: 'Likes', video_ids: [] }
  end

  populate_playlists service, my_playlists
end

def subscription(channel_id)
  res_id = Google::Apis::YoutubeV3::ResourceId.new channel_id: channel_id, kind: 'youtube#channel'
  Google::Apis::YoutubeV3::Subscription.new snippet: Google::Apis::YoutubeV3::SubscriptionSnippet.new(resource_id: res_id)
end

def playlist(name, description)
  snippet = Google::Apis::YoutubeV3::PlaylistSnippet.new title: name, description: description
  status = Google::Apis::YoutubeV3::PlaylistStatus.new privacy_status: 'private'
  Google::Apis::YoutubeV3::Playlist.new snippet: snippet, status: status
end

def playlist_item(playlist_id, video_id)
  res_id = Google::Apis::YoutubeV3::ResourceId.new video_id: video_id, kind: 'youtube#video'
  snippet = Google::Apis::YoutubeV3::PlaylistItemSnippet.new resource_id: res_id, playlist_id: playlist_id
  Google::Apis::YoutubeV3::PlaylistItem.new snippet: snippet
end
