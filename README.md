# Migrate YouTube Data

> Viewers only, not for creators

Automatically gets subscribed channels, personal playlists and saved playlists from the old account.

Ensures the new account:

* subscribes to all the channels with confirmation prompts
* has all personal playlists created with the same title and videos with confirmation prompts
* has all the saved playlists added (WebDriver Automation)

## Pre-requisites

* Ruby
    * `gem install google-api-client` or see [Quickstart guide](https://developers.google.com/youtube/v3/quickstart/ruby)
* [YouTube credentials created](https://developers.google.com/youtube/v3/getting-started#before-you-start) and saved to `auth/` for an OAuth application named **YouTube Data Migration**
    * `auth/old_account_client_secret.json`
    * `auth/new_account_client_secret.json`
* `YouTube Data API v3` enabled on Google APIS Dashboard
* (Optional) Python for saving playlist data and cookies – see below
* The new account has a [Channel](https://www.youtube.com/create_channel)

## Subscriptions and Personal Playlists

Run `ruby migrate.rb` and authenticate your old and new accounts. Confirm each step when prompted.

Alternatively run `YES_TO_ALL=true ruby migrate.rb` to avoid being prompted.

## Saved Playlists

There's no API for managing saved playlists, so we extract them from web traffic data and use web driver for adding them.

### Retrieving The Playlists

You can save the data yourself (using a browser and its developer console) or use a proxy server.

For automatically getting saved playlists data with `mitmproxy`:

1. `pip install mitmproxy` and [trust the certs](https://docs.mitmproxy.org/stable/concepts-certificates/#installing-the-mitmproxy-ca-certificate-manually)
1. In the project root, run `mitmproxy -s ./proxy/save-playlists.py` to start the proxy server
1. Configure proxy settings in your favourite browser for HTTPS traffic and set the server to `localhost:8080`
1. Navigate to your personal YouTube Saved Playlist page and keep scrolling until all playlists are displayed. The URL should be like something like `https://www.youtube.com/user/<username>/playlists?view=52&sort=dd&shelf_id=0`
1. Don't browse any other YouTube page. Quit `mitmproxy` as soon as possible to avoid saving incorrect data made by other AJAX requests.
1. Run `ruby extract-playlists.rb`. The `saved-playlists.py` automatically saves your data in `data/` for `extract-playlists.rb` to process.

### Adding The Playlists

There are two ways:

1. Go on a clicking frenzy. Mind your computer resources if you have lots of playlists!
	* Run `grep ':id:' data/saved-playlists.yaml | awk '{ print $2 }' | xargs -I"{}" open "https://youtube.com/playlist?list={}"` (change the `open` command for your OS).
	* All playlists will be opened in your browser, you just have to click and `Command + w` until they're all saved.
1. Use Selenium and friends
	* `gem install watir` and grab the cookies from authenticated session for you new account with `mitmproxy -s ./proxy/save-cookies.py`
	* I use Safari. Ensure `Develop > Allow Remote Automation` is enabled.
	* Feel free to use other browsers but you have to ensure the driver is available and usable – see [Watir guides](http://watir.com/guides/)
	* Or [go headless](https://readysteadycode.com/howto-use-htmlunit-with-ruby-watir)
	* Run `ruby add-saved-playlists.rb` or `YES_TO_ALL=true ruby add-saved-playlists.rb`

_**FYI:** Selenium Webdriver has never been the most reliable thing in the world. Timed out? just rerun._

## Note

* Subscription list does not included suspended channels even if they are still shown on your sidebar
* Too lazy to use Bundler as we only use at most 2 Gems
