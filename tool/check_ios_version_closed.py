#!/usr/bin/env python3
"""La version de pubspec.yaml est-elle déjà fermée côté App Store Connect ?

Apple refuse tout nouveau build (TestFlight compris) d'une version déjà
soumise à la review, approuvée ou publiée : « train closed » (409). Le build
iOS de 30 min part alors pour rien et le workflow tombe en rouge à chaque
merge. Ce contrôle, lancé avant le build, rend `closed=true` et la raison ;
le workflow saute iOS (Android continue) avec un avertissement clair.
Vaut pour staging comme pour production : le train est le même.

Stdlib seule (JWT signé via `openssl`), comme next_build_number.py.

Variables : ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_APP_ID.
Sortie standard : `closed=true|false` puis `reason=...` (format GITHUB_OUTPUT).
Si Apple ne répond pas : `closed=false` et un avertissement (l'envoi échouera
de lui-même si le train est fermé ; on ne bloque pas un déploiement sain).
"""
import os
import re
import sys
import time
import urllib.parse

import next_build_number as n

# États où Apple n'accepte plus de nouveau build pour cette version.
CLOSED_STATES = {
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "PENDING_APPLE_RELEASE",
    "PENDING_DEVELOPER_RELEASE",
    "PROCESSING_FOR_APP_STORE",
    "READY_FOR_SALE",
    "READY_FOR_DISTRIBUTION",
    "PREORDER_READY_FOR_SALE",
    "ACCEPTED",
    "APPROVED",
    "COMPLETE",
}


def pubspec_version(text: str) -> str:
    m = re.search(r"^version:\s*([0-9]+(?:\.[0-9]+)*)", text, re.M)
    if not m:
        raise ValueError("version introuvable dans pubspec.yaml")
    return m.group(1)


def closed_state(versions: list[dict]) -> str | None:
    """Premier état fermé parmi les versions Apple de ce numéro, sinon None."""
    for v in versions:
        attrs = v.get("attributes", {})
        for key in ("appStoreState", "appVersionState"):
            state = attrs.get(key)
            if state in CLOSED_STATES:
                return state
    return None


def fetch_versions(version: str) -> list[dict]:
    now = int(time.time())
    token = n.jwt(
        "ES256", {"kid": os.environ["ASC_KEY_ID"]},
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        os.environ["ASC_KEY_P8"],
    )
    query = urllib.parse.urlencode({
        "filter[versionString]": version, "filter[platform]": "IOS", "limit": "20",
    })
    url = f"https://api.appstoreconnect.apple.com/v1/apps/{os.environ['ASC_APP_ID']}/appStoreVersions?{query}"
    return n.http(url, token).get("data", [])


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "pubspec.yaml"
    version = pubspec_version(open(path, encoding="utf-8").read())
    try:
        state = closed_state(fetch_versions(version))
    except Exception as e:  # noqa: BLE001 - le message suffit dans le journal CI
        print(f"::warning::Contrôle de la version {version} impossible ({type(e).__name__}: {e}) : iOS tenté quand même.", file=sys.stderr)
        print("closed=false")
        return 0
    if state:
        print("closed=true")
        print(f"reason=La version {version} est déjà {state} chez Apple : plus de nouveau build possible. Monter la version dans pubspec.yaml.")
    else:
        print("closed=false")
    return 0


if __name__ == "__main__":
    sys.exit(main())
