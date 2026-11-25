#!/usr/bin/env python3
"""Pizza-Push: schickt dem Gastgeber eine Push-Nachricht, wenn ein Gast auf der Gästeseite bestellt,
seine Bestellung ändert oder löscht.

So läuft es:
  1. Die Gästeseite (docs/index.html) legt nach jedem Speichern/Löschen eine kleine „Klingel“ in Firestore ab
     (Sammlung `pings`, nur Zeitpunkt + welche Bestellung).
  2. Dieses Programm läuft auf dem Mac mini, schaut alle paar Sekunden nach neuen Klingeln, holt die Bestellung
     und vergleicht sie mit dem letzten bekannten Stand (neu / geändert / gelöscht).
  3. Die App hat ihr Push-Token unter `pushTokens` hinterlegt. An diese Geräte geht die Nachricht direkt über Apple (APNs).

Es braucht nur das, was auf jedem Mac schon da ist: python3, openssl und curl.
Einrichtung: hosting/mac-mini/pizza-push/ANLEITUNG.md

Aufruf:
  python3 pizza_push.py          läuft dauerhaft (so startet es launchd)
  python3 pizza_push.py --test   schickt eine Test-Nachricht an alle angemeldeten Geräte und beendet sich
"""

import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.parse
from datetime import datetime, timezone

HOME = os.environ.get("PIZZA_PUSH_HOME", os.path.expanduser("~/.mgpizza/push"))
CONFIG = os.path.join(HOME, "config.json")
STATE = os.path.join(HOME, "state.json")
GOOGLE_KEY = os.path.join(HOME, "google-key.pem")
INTERVAL = 15          # Sekunden zwischen zwei Abfragen (1 Firestore-Lesevorgang pro Abfrage, gratis bis 50.000/Tag)


def log(*args):
    print(datetime.now().strftime("%Y-%m-%d %H:%M:%S"), *args, flush=True)


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def openssl_sign(key_path, data):
    """SHA-256-Signatur mit dem privaten Schlüssel (RSA: PKCS#1 v1.5, EC: DER)."""
    return subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path],
                          input=data, capture_output=True, check=True).stdout


def der_to_raw(der):
    """ECDSA-Signatur von DER (openssl) in r||s (64 Bytes, für JWT ES256) umwandeln."""
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("unerwartete Signatur")
        length = der[i + 1]
        value = der[i + 2:i + 2 + length]
        i += 2 + length
        out += value.lstrip(b"\x00").rjust(32, b"\x00")
    return out


def curl(method, url, body=None, headers=None, http2=False):
    """HTTP-Anfrage über das curl des Macs (nutzt die Zertifikate von macOS, kann HTTP/2 für Apple)."""
    with tempfile.NamedTemporaryFile() as out:
        cmd = ["curl", "-sS", "-X", method, "-o", out.name, "-w", "%{http_code}", "--max-time", "30"]
        if http2:
            cmd.append("--http2")
        for key, value in (headers or {}).items():
            cmd += ["-H", "%s: %s" % (key, value)]
        if body is not None:
            cmd += ["--data-binary", "@-"]
        result = subprocess.run(cmd + [url], input=body, capture_output=True)
        if result.returncode != 0:
            raise IOError("curl: " + result.stderr.decode(errors="replace").strip())
        out.seek(0)
        return int(result.stdout or 0), out.read()


# ---------- Firestore (als Dienstkonto, unabhängig von den Regeln) ----------

class Firestore:
    def __init__(self, service_account):
        self.sa = service_account
        self.project = service_account["project_id"]
        self.root = "projects/%s/databases/(default)/documents" % self.project
        self.base = "https://firestore.googleapis.com/v1/" + self.root
        self.token = ""
        self.until = 0

    def access_token(self):
        if self.token and time.time() < self.until - 120:
            return self.token
        now = int(time.time())
        header = b64url(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
        claims = b64url(json.dumps({
            "iss": self.sa["client_email"], "scope": "https://www.googleapis.com/auth/datastore",
            "aud": "https://oauth2.googleapis.com/token", "iat": now, "exp": now + 3600}).encode())
        unsigned = "%s.%s" % (header, claims)
        jwt = unsigned + "." + b64url(openssl_sign(GOOGLE_KEY, unsigned.encode()))
        body = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                       "assertion": jwt}).encode()
        status, data = curl("POST", "https://oauth2.googleapis.com/token", body,
                            {"Content-Type": "application/x-www-form-urlencoded"})
        if status != 200:
            raise IOError("Google-Anmeldung fehlgeschlagen (%d): %s" % (status, data[:300]))
        reply = json.loads(data)
        self.token = reply["access_token"]
        self.until = now + int(reply.get("expires_in", 3600))
        return self.token

    def request(self, method, path, body=None):
        headers = {"Authorization": "Bearer " + self.access_token()}
        if body is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(body).encode()
        status, data = curl(method, self.base + path, body, headers)
        if status == 404:
            return None
        if not 200 <= status < 300:
            raise IOError("Firestore %s %s -> %d: %s" % (method, path, status, data[:300]))
        return json.loads(data or b"{}")

    def get(self, path):
        return self.request("GET", "/" + path)

    def delete(self, path):
        self.request("DELETE", "/" + path)

    def query(self, collection, where=None, order_by=None, limit=100):
        q = {"from": [{"collectionId": collection}], "limit": limit}
        if where:
            q["where"] = where
        if order_by:
            q["orderBy"] = [{"field": {"fieldPath": order_by}}]
        rows = self.request("POST", ":runQuery", {"structuredQuery": q}) or []
        return [row["document"] for row in rows if "document" in row]


def field(doc, name):
    """Wert eines Firestore-Felds (Text, Zeitpunkt, Ja/Nein) oder None."""
    value = (doc or {}).get("fields", {}).get(name, {})
    for kind in ("stringValue", "timestampValue", "booleanValue", "integerValue"):
        if kind in value:
            return value[kind]
    return None


def doc_id(doc):
    return doc["name"].rsplit("/", 1)[-1]


# ---------- Apple Push (APNs) ----------

class Apns:
    def __init__(self, config):
        self.key_path = os.path.join(HOME, config["apnsKeyFile"])
        self.key_id = config["apnsKeyId"]
        self.team_id = config["teamId"]
        self.topic = config["bundleId"]
        self.jwt = ""
        self.created = 0

    def token(self):
        # Apple erlaubt ein Token bis zu 60 Minuten, will aber nicht öfter als alle 20 Minuten ein neues
        if self.jwt and time.time() - self.created < 40 * 60:
            return self.jwt
        now = int(time.time())
        header = b64url(json.dumps({"alg": "ES256", "kid": self.key_id}).encode())
        claims = b64url(json.dumps({"iss": self.team_id, "iat": now}).encode())
        unsigned = "%s.%s" % (header, claims)
        self.jwt = unsigned + "." + b64url(der_to_raw(openssl_sign(self.key_path, unsigned.encode())))
        self.created = now
        return self.jwt

    def send(self, device, sandbox, payload, collapse_id=None):
        """Gibt (HTTP-Status, Grund) zurück. 200 = angekommen bei Apple."""
        host = "api.sandbox.push.apple.com" if sandbox else "api.push.apple.com"
        headers = {"authorization": "bearer " + self.token(), "apns-topic": self.topic,
                   "apns-push-type": "alert", "apns-priority": "10"}
        if collapse_id:
            headers["apns-collapse-id"] = collapse_id
        status, data = curl("POST", "https://%s/3/device/%s" % (host, device),
                            json.dumps(payload).encode(), headers, http2=True)
        reason = ""
        if data:
            try:
                reason = json.loads(data).get("reason", "")
            except ValueError:
                reason = data.decode(errors="replace")
        return status, reason


def push_to_host(db, apns, host_uid, title, body, thread, collapse_id=None):
    """Nachricht an alle Geräte schicken, die sich mit dieser Gastgeber-Kennung angemeldet haben (host_uid None = alle)."""
    where = None
    if host_uid is not None:
        where = {"fieldFilter": {"field": {"fieldPath": "hostUid"}, "op": "EQUAL", "value": {"stringValue": host_uid}}}
    devices = db.query("pushTokens", where=where)
    if not devices:
        log("  kein Gerät angemeldet (in der App unter Guest link → Push einschalten)")
    payload = {"aps": {"alert": {"title": title, "body": body}, "sound": "default", "thread-id": thread},
               "guestEvent": thread}
    for device in devices:
        token = doc_id(device)
        status, reason = apns.send(token, field(device, "sandbox") is True, payload, collapse_id)
        if status == 200:
            log("  Push gesendet an …%s" % token[-6:])
        elif status == 410 or reason in ("BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"):
            log("  Gerät …%s nicht mehr gültig (%s), wird entfernt" % (token[-6:], reason or status))
            db.delete("pushTokens/" + token)
        else:
            log("  Push fehlgeschlagen (%d %s)" % (status, reason))


# ---------- Bestellungen vergleichen ----------

def describe(order):
    """Kurzfassung einer Bestellung, z. B. „2× Margherita (ohne Basilikum), 1× Eigene Pizza (Salami)“."""
    parts = []
    for line in order.get("lines", []):
        text = "%s× %s" % (line.get("count", 1), line.get("name", "?"))
        if line.get("custom"):
            text += " (%s)" % ", ".join(t.get("name", "") for t in line["custom"])
        if line.get("extra"):
            text += " + " + ", ".join(line["extra"])
        if line.get("without"):
            text += " (ohne %s)" % ", ".join(line["without"])
        parts.append(text)
    if order.get("note"):
        parts.append("„%s“" % order["note"])
    return ", ".join(parts)


def load_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_state(state):
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE)


def now_rfc3339():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def handle_ping(db, apns, state, ping):
    event_id, order_id = field(ping, "event"), field(ping, "order")
    if not event_id or not order_id or "/" in event_id or "/" in order_id:
        return
    key = "%s/%s" % (event_id, order_id)
    known = state["orders"].get(key)
    doc = db.get("events/%s/orders/%s" % (event_id, order_id))
    data = field(doc, "data")
    if data == known:
        return  # nichts geändert (z. B. Bestellung unverändert nochmal abgeschickt)
    event = db.get("events/" + event_id)
    if event is None:
        return
    try:
        title = json.loads(field(event, "data") or "{}").get("title") or "Pizzaabend"
    except ValueError:
        title = "Pizzaabend"
    if data is None:
        if known is None and field(ping, "action") != "delete":
            return
        try:
            guest = json.loads(known or "{}").get("guest") or order_id
        except ValueError:
            guest = order_id
        body = "%s hat die Bestellung gelöscht" % guest
        state["orders"].pop(key, None)
    else:
        try:
            order = json.loads(data)
        except ValueError:
            return
        verb = "hat bestellt" if known is None else "hat die Bestellung geändert"
        body = "%s %s: %s" % (order.get("guest", order_id), verb, describe(order))
        state["orders"][key] = data
    log("%s – %s" % (title, body))
    collapse = hashlib.sha256(key.encode()).hexdigest()[:32]   # mehrere Änderungen derselben Bestellung ersetzen sich
    push_to_host(db, apns, field(event, "hostUid") or "", "🍕 " + title, body, event_id, collapse)


def check(db, apns, state):
    where = {"fieldFilter": {"field": {"fieldPath": "at"}, "op": "GREATER_THAN",
                             "value": {"timestampValue": state["lastSeen"]}}}
    for ping in db.query("pings", where=where, order_by="at", limit=50):
        try:
            handle_ping(db, apns, state, ping)
        except Exception as error:   # eine kaputte Bestellung soll die anderen nicht aufhalten
            log("Fehler bei %s: %s" % (doc_id(ping), error))
        state["lastSeen"] = field(ping, "at") or state["lastSeen"]
        save_state(state)


def setup():
    with open(CONFIG) as f:
        config = json.load(f)
    with open(os.path.join(HOME, config["serviceAccountFile"])) as f:
        service_account = json.load(f)
    if not os.path.exists(GOOGLE_KEY):
        fd = os.open(GOOGLE_KEY, os.O_WRONLY | os.O_CREAT, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(service_account["private_key"])
    return Firestore(service_account), Apns(config)


def main():
    db, apns = setup()
    if "--test" in sys.argv:
        log("Test-Nachricht an alle angemeldeten Geräte …")
        push_to_host(db, apns, None, "🍕 Pizza-Push", "Test vom Mac mini: Push funktioniert!", "test")
        return
    state = load_state()
    state.setdefault("orders", {})
    state.setdefault("lastSeen", now_rfc3339())   # beim ersten Start: nur was ab jetzt passiert
    save_state(state)
    log("Pizza-Push läuft (Projekt %s), schaut alle %d Sekunden nach." % (db.project, INTERVAL))
    pause = INTERVAL
    while True:
        try:
            check(db, apns, state)
            pause = INTERVAL
        except Exception as error:
            log("Fehler: %s" % error)
            pause = min(pause * 2, 300)   # bei Netzproblemen langsamer werden
        time.sleep(pause)


if __name__ == "__main__":
    main()
