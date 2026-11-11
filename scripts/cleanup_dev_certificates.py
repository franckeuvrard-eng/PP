"""Revoque les certificats de developpement crees par l'integration continue.

A chaque compilation, la machine GitHub est neuve : Xcode y cree un
certificat « Apple Development » via la cle API App Store Connect. Ils
s'accumulent jusqu'a la limite d'Apple, qui bloque alors la signature
(« Your account has reached the maximum number of certificates »).

Ne touche QUE les certificats de developpement nommes « Created via API »
(ceux de l'integration continue) : jamais un certificat de distribution, ni
celui cree par Xcode sur le Mac de l'enseignant (qui porte son nom).
Les applications deja publiees n'en dependent pas.

Usage : python3 cleanup_dev_certificates.py KEY_ID ISSUER_ID chemin/AuthKey.p8
"""
import json
import sys
import time
import urllib.request

import jwt  # pip install "pyjwt[crypto]"

API = 'https://api.appstoreconnect.apple.com/v1'
DEV_TYPES = 'DEVELOPMENT,IOS_DEVELOPMENT,MAC_APP_DEVELOPMENT'
CI_MARK = 'Created via API'


def token(key_id, issuer, key_path):
    now = int(time.time())
    return jwt.encode(
        {'iss': issuer, 'iat': now, 'exp': now + 15 * 60, 'aud': 'appstoreconnect-v1'},
        open(key_path).read(),
        algorithm='ES256',
        headers={'kid': key_id, 'typ': 'JWT'},
    )


def call(method, url, tok):
    req = urllib.request.Request(url, method=method, headers={'Authorization': f'Bearer {tok}'})
    with urllib.request.urlopen(req, timeout=30) as res:
        body = res.read()
        return json.loads(body) if body else None


def main():
    key_id, issuer, key_path = sys.argv[1:4]
    tok = token(key_id, issuer, key_path)
    data = call('GET', f'{API}/certificates?filter[certificateType]={DEV_TYPES}&limit=200', tok)
    certs = data.get('data', [])
    ci = [c for c in certs
          if CI_MARK in (c['attributes'].get('displayName') or '')
          or CI_MARK in (c['attributes'].get('name') or '')]
    print(f'{len(certs)} certificat(s) de developpement, dont {len(ci)} de l\'integration continue.')
    for c in ci:
        a = c['attributes']
        call('DELETE', f"{API}/certificates/{c['id']}", tok)
        print(f"Revoque : {a.get('name')} ({a.get('certificateType')}, expire {a.get('expirationDate')})")


if __name__ == '__main__':
    main()
