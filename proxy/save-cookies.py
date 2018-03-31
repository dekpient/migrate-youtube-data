from mitmproxy import flow
import os
import json

COOKIES = 'auth/cookies.json'


def response(flow):
    req = flow.request
    if ('youtube' in req.host) and (not os.path.isfile(COOKIES) or
                                    os.stat(COOKIES).st_size == 0):
            with open(COOKIES, 'w') as f:
                json.dump(dict(req.cookies.items(multi=True)), f)
