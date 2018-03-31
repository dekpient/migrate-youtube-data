# http://2qwesgdhjuiytyrjhtgdbf.readthedocs.io/en/latest/dev/models.html
from mitmproxy import flow


def response(flow):
    req = flow.request
    count = 1
    if 'youtube' in req.host:
        # playlists?view=52&sort=dd&shelf_id=0
        # first page
        if 'playlists' in req.path and '52' in req.query.get_all('view'):
            with open('data/saved-playlists.html', 'wb') as f:
                f.write(flow.response.content)
            return
        # more content after scrolling
        if 'browse_ajax' in req.path:
            with open('data/more-saved-playlists-%d.json' % count, 'wb') as f:
                f.write(flow.response.content)
                count = count + 1
            return
