require 'watir'
require 'yaml'

require_relative 'lib/helper'

BROWSER = :safari

# Who knows when these will change
SAVE_ICON_ATTR = 'M14 10H2v2h12v-2zm0-4H2v2h12V6zm4 8v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zM2 16h8v-2H2v2z'
ALREADY_SAVED_ICON_ATTR = 'M14 10H2v2h12v-2zm0-4H2v2h12V6zM2 16h8v-2H2v2zm19.5-4.5L23 13l-6.99 7-4.51-4.5L13 14l3.01 3 5.49-5.5z'

auth_cookies = JSON.load File.read 'auth/cookies.json'
saved_playlists = YAML.load File.read './data/saved-playlists.yaml'

Watir.relaxed_locate = true

browser = Watir::Browser.new BROWSER
browser.goto 'youtube.com'
auth_cookies.each { |n, v| browser.cookies.add n, v, path: '/', expires: Date.today.next_day, secure: false, domain: '.youtube.com' }

[saved_playlists[0], saved_playlists[1]].each do |pl|
  browser.goto "youtube.com/playlist?list=#{pl[:id]}"
  icon = browser.element(css: 'button[aria-label="Save playlist"] path.yt-icon')
  icon_attr = icon.attribute_value('d')
  puts "Playlist '#{pl[:name]}' is already saved" if icon_attr == ALREADY_SAVED_ICON_ATTR
  next if icon_attr == ALREADY_SAVED_ICON_ATTR

  raise('YouTube has been updated? The icon has unexpected attribute value. Fix the script first!') unless icon_attr == SAVE_ICON_ATTR

  next unless confirm?("Saving playlist '#{pl[:name]}' from channel '#{pl[:channel_name]}'")
  browser.element(css: 'button[aria-label="Save playlist"]').click
  Watir::Wait.until { browser.text.include? 'Added to Library' }
end

browser.close
