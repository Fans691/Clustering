#!/usr/bin/env python3
"""Serveur d'administration web pour HAProxy."""

import http.server
import json
import os
import re
import subprocess
import tempfile

PORT = 4000
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
HAPROXY_CFG_LOCAL = os.path.join(PROJECT_DIR, 'haproxy.cfg')
HAPROXY_CFG_SYSTEM = '/etc/haproxy/haproxy.cfg'


def parse_config(config_text):
    """Parse haproxy.cfg and return structured data."""
    result = {
        'bind_port': 8082,
        'balance': 'roundrobin',
        'health_check': '/a.html',
        'servers': [],
    }

    current_section = None
    for line in config_text.split('\n'):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue

        if re.match(r'^(global|defaults|frontend|backend)\b', stripped):
            current_section = stripped
            continue

        if current_section and current_section.startswith('frontend http_front'):
            m = re.match(r'bind\s+\*:(\d+)', stripped)
            if m:
                result['bind_port'] = int(m.group(1))

        if current_section and current_section.startswith('backend web_servers'):
            m = re.match(r'balance\s+(\w+)', stripped)
            if m:
                result['balance'] = m.group(1)

            m = re.match(r'option\s+httpchk\s+GET\s+(\S+)', stripped)
            if m:
                result['health_check'] = m.group(1)

            m = re.match(r'server\s+(\S+)\s+(\S+):(\d+)(\s+check)?', stripped)
            if m:
                result['servers'].append({
                    'name': m.group(1),
                    'address': m.group(2),
                    'port': int(m.group(3)),
                    'check': bool(m.group(4)),
                })

    return result


def generate_config(data):
    """Generate haproxy.cfg from structured data."""
    bind_port = int(data.get('bind_port', 8082))
    balance = data.get('balance', 'roundrobin')
    health_check = data.get('health_check', '/a.html')
    servers = data.get('servers', [])

    server_lines = ''
    for s in servers:
        name = re.sub(r'[^a-zA-Z0-9_-]', '', s.get('name', 'server'))
        address = s.get('address', '127.0.0.1')
        port = int(s.get('port', 80))
        check = ' check' if s.get('check', True) else ''
        server_lines += f'    server {name} {address}:{port}{check}\n'

    return (
        'global\n'
        '\tlog /dev/log\tlocal0\n'
        '\tlog /dev/log\tlocal1 notice\n'
        '\tchroot /var/lib/haproxy\n'
        '\tstats socket /run/haproxy/admin.sock mode 660 level admin\n'
        '\tstats timeout 30s\n'
        '\tuser haproxy\n'
        '\tgroup haproxy\n'
        '\tdaemon\n'
        '\n'
        '\tca-base /etc/ssl/certs\n'
        '\tcrt-base /etc/ssl/private\n'
        '\n'
        '        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384\n'
        '        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256\n'
        '        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets\n'
        '\n'
        'defaults\n'
        '\tlog\tglobal\n'
        '\tmode\thttp\n'
        '\toption\thttplog\n'
        '\toption\tdontlognull\n'
        '        timeout connect 5000\n'
        '        timeout client  50000\n'
        '        timeout server  50000\n'
        '\terrorfile 400 /etc/haproxy/errors/400.http\n'
        '\terrorfile 403 /etc/haproxy/errors/403.http\n'
        '\terrorfile 408 /etc/haproxy/errors/408.http\n'
        '\terrorfile 500 /etc/haproxy/errors/500.http\n'
        '\terrorfile 502 /etc/haproxy/errors/502.http\n'
        '\terrorfile 503 /etc/haproxy/errors/503.http\n'
        '\terrorfile 504 /etc/haproxy/errors/504.http\n'
        '\n'
        'frontend http_front\n'
        f'    bind *:{bind_port}\n'
        '    mode http\n'
        '    default_backend web_servers\n'
        '\n'
        'frontend stats\n'
        '    bind *:8083\n'
        '    mode http\n'
        '    stats enable\n'
        '    stats uri /\n'
        '    stats refresh 5s\n'
        '    stats realm HAProxy\\ Statistiques\n'
        '\n'
        'backend web_servers\n'
        '    mode http\n'
        f'    balance {balance}\n'
        f'    option httpchk GET {health_check}\n'
        '    http-response set-header X-Backend-Server %s\n'
        f'{server_lines}'
    )


class HAProxyAdminHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f'[{self.log_date_time_string()}] {fmt % args}')

    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self._serve_file('index.html', 'text/html')
        elif self.path == '/api/parsed':
            self._get_parsed()
        elif self.path == '/api/status':
            self._get_status()
        else:
            self._send_error(404, 'Non trouve')

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b''

        if self.path == '/api/parsed':
            self._save_parsed(body)
        elif self.path == '/api/validate':
            self._validate_config(body)
        elif self.path == '/api/restart':
            self._restart_haproxy()
        else:
            self._send_error(404, 'Non trouve')

    def _serve_file(self, filename, content_type):
        path = os.path.join(SCRIPT_DIR, filename)
        try:
            with open(path, 'rb') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', f'{content_type}; charset=utf-8')
            self.send_header('Content-Length', len(content))
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            self._send_error(404, 'Fichier non trouve')

    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, status, message):
        self._send_json({'error': message}, status)

    def _get_parsed(self):
        try:
            with open(HAPROXY_CFG_LOCAL, 'r') as f:
                config_text = f.read()
            parsed = parse_config(config_text)
            self._send_json(parsed)
        except FileNotFoundError:
            self._send_json(
                {'error': f'Fichier non trouve: {HAPROXY_CFG_LOCAL}'}, 404
            )
        except Exception as e:
            self._send_json({'error': str(e)}, 500)

    def _save_parsed(self, body):
        try:
            data = json.loads(body)
            servers = data.get('servers', [])
            if not servers:
                self._send_json(
                    {'error': 'Il faut au moins un serveur.'}, 400
                )
                return
            names = [s.get('name', '') for s in servers]
            if len(names) != len(set(names)):
                self._send_json(
                    {'error': 'Les noms de serveurs doivent etre uniques.'}, 400
                )
                return
            config = generate_config(data)
            with open(HAPROXY_CFG_LOCAL, 'w') as f:
                f.write(config)
            self._send_json({
                'message': f'Configuration sauvegardee: {HAPROXY_CFG_LOCAL}',
                'preview': config,
            })
        except json.JSONDecodeError:
            self._send_json({'error': 'JSON invalide.'}, 400)
        except Exception as e:
            self._send_json({'error': str(e)}, 500)

    def _validate_config(self, body):
        try:
            data = json.loads(body)
            config = data.get('config', '')
            fd, tmp_path = tempfile.mkstemp(suffix='.cfg')
            try:
                with os.fdopen(fd, 'w') as tmp:
                    tmp.write(config)
                result = subprocess.run(
                    ['haproxy', '-c', '-f', tmp_path],
                    capture_output=True, text=True, timeout=10,
                )
                self._send_json({
                    'valid': result.returncode == 0,
                    'stdout': result.stdout,
                    'stderr': result.stderr,
                })
            finally:
                os.unlink(tmp_path)
        except json.JSONDecodeError:
            self._send_json({'error': 'JSON invalide.'}, 400)
        except FileNotFoundError:
            self._send_json(
                {'error': 'haproxy non installe ou introuvable dans le PATH.'},
                500,
            )
        except Exception as e:
            self._send_json({'error': str(e)}, 500)

    def _restart_haproxy(self):
        try:
            deploy = subprocess.run(
                ['sudo', 'cp', HAPROXY_CFG_LOCAL, HAPROXY_CFG_SYSTEM],
                capture_output=True, text=True, timeout=10,
            )
            if deploy.returncode != 0:
                self._send_json(
                    {'error': f'Echec du deploiement: {deploy.stderr.strip()}'},
                    500,
                )
                return

            result = subprocess.run(
                ['sudo', 'systemctl', 'restart', 'haproxy'],
                capture_output=True, text=True, timeout=15,
            )
            if result.returncode == 0:
                self._send_json(
                    {'message': 'Configuration deployee et HAProxy redemarre.'}
                )
            else:
                self._send_json({'error': result.stderr.strip()}, 500)
        except Exception as e:
            self._send_json({'error': str(e)}, 500)

    def _get_status(self):
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', 'haproxy'],
                capture_output=True, text=True, timeout=5,
            )
            status = result.stdout.strip()
            self._send_json({
                'status': status,
                'active': status == 'active',
            })
        except Exception as e:
            self._send_json({'error': str(e)}, 500)


def main():
    server = http.server.HTTPServer(('0.0.0.0', PORT), HAProxyAdminHandler)
    print(f'HAProxy Admin demarre sur http://localhost:{PORT}')
    print(f'Configuration locale: {HAPROXY_CFG_LOCAL}')
    print('Ctrl+C pour arreter.')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nArret du serveur.')
        server.server_close()


if __name__ == '__main__':
    main()
