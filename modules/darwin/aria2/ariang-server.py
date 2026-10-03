import functools
import http.client
import json
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import cast
from urllib.parse import unquote, urlsplit


def authenticate(call, token):
    if not isinstance(call, dict) or not isinstance(call.get('method'), str):
        raise ValueError('Invalid RPC request')

    method = call['method']
    params = call.setdefault('params', [])
    if not isinstance(params, list):
        raise ValueError('Invalid RPC parameters')

    if method.startswith('aria2.'):
        first = params[0] if params else None
        if isinstance(first, str) and first.startswith('token:'):
            params.pop(0)
        params.insert(0, token)
    elif method == 'system.multicall':
        if len(params) != 1 or not isinstance(params[0], list):
            raise ValueError('Invalid multicall parameters')
        for item in params[0]:
            if not isinstance(item, dict):
                raise ValueError('Invalid multicall request')
            nested = {
                'method': item.get('methodName'),
                'params': item.get('params', []),
            }
            if nested['method'] == 'system.multicall':
                raise ValueError('Invalid multicall method')
            authenticate(nested, token)
            item['params'] = nested['params']
    elif method not in ('system.listMethods', 'system.listNotifications'):
        raise ValueError('Invalid RPC method')


class Server(ThreadingHTTPServer):
    authority: str
    origin: str
    rpc_port: int
    token: str


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        super().end_headers()

    def log_message(self, format, *args):
        pass

    def list_directory(self, path):
        self.send_error(403)

    def allowed_host(self):
        if self.headers.get('Host') != cast(Server, self.server).authority:
            self.send_error(403)
            return False
        return True

    def do_GET(self):
        if self.allowed_host():
            super().do_GET()

    def do_HEAD(self):
        if self.allowed_host():
            super().do_HEAD()

    def send_head(self):
        # Nix store timestamps do not distinguish rebuilt frontend assets.
        del self.headers['If-Modified-Since']
        return super().send_head()

    def translate_path(self, path):
        relative = unquote(urlsplit(path).path).lstrip('/')
        target = (Path(self.directory) / relative).resolve()
        if not target.is_relative_to(Path(self.directory)):
            return str(Path(self.directory) / '__forbidden__')
        return str(target)

    def do_POST(self):
        if not self.allowed_host():
            return
        server = cast(Server, self.server)
        if self.path != '/jsonrpc':
            self.send_error(404)
            return
        if self.headers.get('Origin') != server.origin:
            self.send_error(403)
            return
        if self.headers.get_content_type() != 'application/json':
            self.send_error(415)
            return

        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 2 * 1024 * 1024:
                self.send_error(413)
                return
            payload = json.loads(self.rfile.read(length))
            calls = payload if isinstance(payload, list) else [payload]
            if not calls:
                raise ValueError('Empty RPC batch')
            for call in calls:
                authenticate(call, server.token)
        except ValueError:
            self.send_error(400)
            return

        connection = http.client.HTTPConnection(
            '127.0.0.1', server.rpc_port, timeout=15
        )
        try:
            connection.request(
                'POST',
                '/jsonrpc',
                json.dumps(payload),
                {'Content-Type': 'application/json'},
            )
            response = connection.getresponse()
            body = response.read()
            self.send_response(response.status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except OSError:
            self.send_error(502)
        except http.client.HTTPException:
            self.send_error(502)
        finally:
            connection.close()


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    lines = Path(config['rpcConfig']).read_text().splitlines()
    secret = next(
        (
            line.removeprefix('rpc-secret=')
            for line in lines
            if line.startswith('rpc-secret=')
        ),
        '',
    )
    if not secret:
        raise ValueError('Missing aria2 RPC secret')

    handler = functools.partial(Handler, directory=config['assets'])
    with Server(('127.0.0.1', config['port']), handler) as server:
        server.authority = f'127.0.0.1:{config["port"]}'
        server.origin = f'http://{server.authority}'
        server.rpc_port = config['rpcPort']
        server.token = f'token:{secret}'
        server.serve_forever()


if __name__ == '__main__':
    main()
