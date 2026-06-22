"""Seed dummy study_sessions + mood_journals for Fase 4 history testing.

Run via run_seed.sh which provides SB_URL, SB_ANON, SB_TOKEN env vars.
Uses only the Python stdlib (urllib). Idempotency: tags dummy sessions with a
recognizable notes marker and deletes prior dummy rows before re-seeding.
"""
import os, json, base64, random, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone

URL = os.environ["SB_URL"].rstrip("/")
ANON = os.environ["SB_ANON"]
TOKEN = os.environ["SB_TOKEN"]
MARKER = "[seed-f4]"
random.seed(42)

def _hdr(extra=None):
    h = {"apikey": ANON, "Authorization": f"Bearer {TOKEN}",
         "Content-Type": "application/json"}
    if extra: h.update(extra)
    return h

def req(method, path, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(URL + path, data=data, method=method,
                               headers=_hdr(headers))
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, e.read().decode()[:400]); raise

# --- user id from JWT 'sub' ---
payload = TOKEN.split(".")[1]
payload += "=" * (-len(payload) % 4)
USER_ID = json.loads(base64.urlsafe_b64decode(payload))["sub"]
print("user:", USER_ID)

# --- topics: ensure the set exists ---
existing = req("GET", "/rest/v1/topics?select=id,name")
topic_ids = {t["name"]: t["id"] for t in existing}
for name in ["Matematika", "Sejarah", "Fisika", "Bahasa Inggris"]:
    if name not in topic_ids:
        row = req("POST", "/rest/v1/topics",
                  [{"user_id": USER_ID, "name": name}],
                  {"Prefer": "return=representation"})
        topic_ids[name] = row[0]["id"]
        print("created topic", name)
print("topics:", list(topic_ids))

# --- mood parameters ---
params = req("GET", "/rest/v1/mood_parameters?select=id,name")
param_id = {p["name"]: p["id"] for p in params}

# --- an ambient sound id (optional, for some sessions) ---
amb = req("GET", "/rest/v1/ambient_sounds?select=id,name&limit=1")
amb_id = amb[0]["id"] if amb else None

# --- clean previous dummy rows (cascade removes their mood_journals) ---
old = req("GET", f"/rest/v1/study_sessions?select=id&notes=like.*{MARKER}*")
if old:
    req("DELETE", f"/rest/v1/study_sessions?notes=like.*{MARKER}*")
    print("deleted", len(old), "old dummy sessions")

# Per-topic baseline mood (mood_umum, fokus, kelelahan, motivasi) 1-5
baseline = {
    "Matematika":      {"mood_umum": 4, "fokus": 5, "kelelahan": 4, "motivasi": 5},
    "Fisika":          {"mood_umum": 4, "fokus": 4, "kelelahan": 3, "motivasi": 4},
    "Sejarah":         {"mood_umum": 3, "fokus": 2, "kelelahan": 2, "motivasi": 3},
    "Bahasa Inggris":  {"mood_umum": 4, "fokus": 4, "kelelahan": 4, "motivasi": 3},
}
# how many sessions per topic
plan = {"Matematika": 6, "Sejarah": 5, "Fisika": 5, "Bahasa Inggris": 4}
hours = [7, 9, 13, 14, 16, 17, 20, 22]  # spread across pagi/siang/sore/malam

now = datetime.now(timezone.utc)
sessions = []
meta = []  # parallel: (topic, status)
day = 0
for topic, count in plan.items():
    for _ in range(count):
        day = (day + 2) % 25
        started = (now - timedelta(days=day)).replace(
            hour=random.choice(hours), minute=random.randint(0, 59), second=0)
        is_pomo = random.random() < 0.6
        completed = random.random() < 0.7
        if is_pomo:
            planned = random.choice([1500, 1800, 3000])  # 25/30/50 min
            actual = planned if completed else int(planned * random.uniform(0.3, 0.8))
        else:
            planned = None
            actual = random.choice([600, 900, 1200, 1500])
        ended = started + timedelta(seconds=actual)
        sessions.append({
            "user_id": USER_ID, "topic_id": topic_ids[topic],
            "mode": "pomodoro" if is_pomo else "stopwatch",
            "started_at": started.isoformat(), "ended_at": ended.isoformat(),
            "planned_duration_sec": planned, "actual_duration_sec": actual,
            "status": "completed" if completed else "stopped_early",
            "ambient_sound_id": amb_id if random.random() < 0.5 else None,
            "notes": MARKER,
        })
        meta.append(topic)

inserted = req("POST", "/rest/v1/study_sessions", sessions,
               {"Prefer": "return=representation"})
print("inserted", len(inserted), "sessions")

# --- moods per session, correlated to topic with small jitter ---
mood_rows = []
for sess, topic in zip(inserted, meta):
    base = baseline[topic]
    for pname, pid in param_id.items():
        b = base.get(pname, 3)
        score = max(1, min(5, b + random.choice([-1, 0, 0, 1])))
        mood_rows.append({
            "user_id": USER_ID, "session_id": sess["id"],
            "mood_parameter_id": pid, "score": score,
            "note": "Catatan dummy seed." if pname == "mood_umum" and random.random() < 0.3 else None,
        })
req("POST", "/rest/v1/mood_journals", mood_rows)
print("inserted", len(mood_rows), "mood rows")
print("DONE: total dummy sessions =", len(inserted))
