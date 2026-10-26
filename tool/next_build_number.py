#!/usr/bin/env python3
"""Prochain numéro de build, commun à iOS et Android.

Lit le plus grand numéro déjà envoyé à App Store Connect et à Google Play,
puis rend ce maximum + 1. Les builds faits à la main et ceux de la CI suivent
ainsi la même suite, sans saut ni collision.

Stdlib seule (la signature des JWT passe par `openssl`) : ce script tourne avec
les secrets de signature, pas de dépendance à installer.

Variables d'environnement :
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8   clé API App Store Connect
  ASC_APP_ID                              identifiant Apple de l'app
  PLAY_SERVICE_ACCOUNT_JSON               compte de service Google Play
  PLAY_PACKAGE_NAME                       ex. com.yadony.yadony
  BUILD_NUMBER_FLOOR                      (facultatif) plus petit numéro déjà consommé

Le plancher couvre un angle mort d'App Store Connect : un build qu'on vient
d'envoyer n'est listé par l'API qu'une fois son traitement commencé. Sans lui,
un déploiement lancé juste après un autre pourrait reprendre le même numéro.

Échoue (code 1) si l'un des deux stores ne répond pas : mieux vaut ne pas
déployer qu'inventer un numéro.
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request


def b64url(data: bytes) -> bytes:
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def der_to_raw(der: bytes, size: int = 32) -> bytes:
    """Signature ECDSA DER (SEQUENCE{INTEGER r, INTEGER s}) -> r||s, comme l'exige ES256."""
    if der[0] != 0x30:
        raise ValueError("signature DER inattendue")
    i = 2 + (der[1] & 0x7F) if der[1] & 0x80 else 2
    parts = []
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("entier DER attendu")
        n = der[i + 1]
        parts.append(der[i + 2:i + 2 + n].lstrip(b"\x00").rjust(size, b"\x00"))
        i += 2 + n
    return b"".join(parts)


def jwt(alg: str, header: dict, claims: dict, pem: str) -> str:
    h = dict(header, alg=alg, typ="JWT")
    signing_input = b64url(json.dumps(h).encode()) + b"." + b64url(json.dumps(claims).encode())
    with tempfile.NamedTemporaryFile("w", suffix=".pem") as f:
        f.write(pem)
        f.flush()
        sig = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", f.name],
            input=signing_input, capture_output=True, check=True,
        ).stdout
    if alg == "ES256":
        sig = der_to_raw(sig)
    return (signing_input + b"." + b64url(sig)).decode()


def http(url: str, token: str, method: str = "GET", body: bytes | None = None, ctype: str | None = None):
    req = urllib.request.Request(url, data=body, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if ctype:
        req.add_header("Content-Type", ctype)
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read()
    return json.loads(raw) if raw else {}


def max_int(values) -> int:
    nums = [int(v) for v in values if str(v).isdigit()]
    return max(nums, default=0)


def apple_latest() -> int:
    now = int(time.time())
    token = jwt(
        "ES256", {"kid": os.environ["ASC_KEY_ID"]},
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        os.environ["ASC_KEY_P8"],
    )
    query = urllib.parse.urlencode({
        "filter[app]": os.environ["ASC_APP_ID"], "fields[builds]": "version", "limit": "200",
    })
    url = f"https://api.appstoreconnect.apple.com/v1/builds?{query}"
    versions = []
    while url:
        page = http(url, token)
        versions += [b["attributes"]["version"] for b in page.get("data", [])]
        url = page.get("links", {}).get("next")
    return max_int(versions)


def play_latest() -> int:
    sa = json.loads(os.environ["PLAY_SERVICE_ACCOUNT_JSON"])
    now = int(time.time())
    assertion = jwt(
        "RS256", {},
        {"iss": sa["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
         "aud": "https://oauth2.googleapis.com/token", "iat": now, "exp": now + 600},
        sa["private_key"],
    )
    form = urllib.parse.urlencode({
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion,
    }).encode()
    token = http("https://oauth2.googleapis.com/token", "", "POST", form,
                 "application/x-www-form-urlencoded")["access_token"]
    base = ("https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
            + os.environ["PLAY_PACKAGE_NAME"])
    edit = http(f"{base}/edits", token, "POST", b"{}", "application/json")["id"]
    try:
        bundles = http(f"{base}/edits/{edit}/bundles", token).get("bundles", [])
        tracks = http(f"{base}/edits/{edit}/tracks", token).get("tracks", [])
    finally:
        # Une édition ouverte puis abandonnée expire seule ; on la ferme quand même.
        try:
            http(f"{base}/edits/{edit}", token, "DELETE")
        except Exception:
            pass
    codes = [b["versionCode"] for b in bundles]
    for t in tracks:
        for rel in t.get("releases", []):
            codes += rel.get("versionCodes", [])
    return max_int(codes)


def main() -> int:
    try:
        apple, play = apple_latest(), play_latest()
    except Exception as e:  # noqa: BLE001 - on veut le message, pas la pile, dans le journal CI
        print(f"ÉCHEC : lecture des numéros de build impossible ({type(e).__name__}: {e})", file=sys.stderr)
        return 1
    floor = int(os.environ.get("BUILD_NUMBER_FLOOR") or 0)
    nxt = max(apple, play, floor) + 1
    print(f"App Store Connect : {apple} | Google Play : {play} | plancher : {floor} | prochain : {nxt}", file=sys.stderr)
    print(nxt)
    return 0


if __name__ == "__main__":
    sys.exit(main())
