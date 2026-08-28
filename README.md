# CogniCare NER

An **offline-first, elderly-friendly cognitive-care platform** for dementia
patients — built with Flutter for **Android + Web**. Patients play calm cognitive
games; caregivers set up the device, monitor progress, and get gentle early
warnings; doctors review trends on a read-only web dashboard.

> SIH 2025 · PS3 · Repo: `SIH2026_PROJECT_PS3`. The Flutter project lives in
> [`cognicare_ner/`](cognicare_ner/).

---

## The three roles

| Role | Auth | Runs on | What they do |
|---|---|---|---|
| **Patient** | anonymous (no login) | tablet / phone | Big single-tap cognitive games, family-voice reminders, Calm mode |
| **Caregiver** | email / password | phone | Create the patient, view the progress dashboard, get drop alerts |
| **Doctor** | email / password | laptop (web) | Read-only dashboard: trends, sessions, alerts, printable weekly report |

Run all three from one app (role picker + one-tap switch) or as locked per-role
builds. See [RUN.md](RUN.md).

## Stack

Flutter 3.44 · Firebase (Auth + Cloud Firestore, **free Spark plan**) · Hive
(offline store) · fl_chart · just_audio · flutter_tts · speech_to_text · record ·
google_fonts · flutter_localizations · http + flutter_dotenv (AI keys) ·
connectivity_plus.

## Architecture (short)

```
   +--------------+   +---------------+   +---------------+
   |  PATIENT app |   | CAREGIVER app |   |   DOCTOR web  |
   | (anon, games)|   | (email login) |   | (email, r/o)  |
   +------+-------+   +-------+-------+   +-------+-------+
          | writes           | setup            | reads
          v                  v                  v
   +---------------------------------------------------------+
   |   Hive LocalDb  (offline-first, one store per device)   |
   |  profile . media . reminders . sessions . alerts . queue|
   +----------------------------+----------------------------+
                                | SyncService: queue drains when online,
                                v pulls the patient's cloud docs back
   +---------------------------------------------------------+
   |         Firebase  (Auth + Firestore, free tier)         |
   |  patients/{id}/{sessions,reminders,media,dailyCare,     |
   |  alerts}  .  caregivers/{uid}  .  doctors/{uid}          |
   +---------------------------------------------------------+
   On-device AI : Tier-1 difficulty rule + cognitive-drop detector
   Optional cloud AI : Groq / Gemini (caregiver notes) + Whisper (STT)
```

## How offline works

Every write goes to **Hive first** (instant, works with no network) and is also
appended to a **sync queue**. `SyncService` listens to connectivity; when a
connection returns it **drains the queue** to Firestore and **pulls** the
patient's cloud documents back into Hive (cloud-wins for profile/media/reminders,
local-wins for append-only sessions). The UI only ever reads the local store, so
games, reminders, and Calm mode all work fully offline; the doctor dashboard
keeps a local cache for offline viewing. Media (family photos/voice/music) stays
on-device — no paid Cloud Storage needed.

## How the AI works

**Adaptive difficulty (2 tiers).**
- *Tier 1 — on-device, always on, offline:* over the last up-to-5 results per
  game, average accuracy **> 0.85 → level +1**, **< 0.50 → level −1**, else hold
  (clamped 1–5, persisted per game). Sequence length, option count, and
  distractors scale with the level.
- *Tier 2 — optional, online:* asks Groq (`llama-3.3-70b`) → Gemini fallback for a
  suggested level + a one-line caregiver note; if it disagrees by one level it is
  preferred. Fails gracefully to Tier 1 (no keys / offline / error).

**Cognitive-drop detection (explainable).** Per domain, once there are ≥ 8
chronological results: `baseline = mean(all but last 3)`, `recent = mean(last 3)`;
if `(baseline − recent) / baseline > 0.22` a `cognitive_drop` alert is raised
(debounced to once per domain per 7 days). It surfaces as a **gentle caregiver
banner** ("consider consulting a doctor") and a **red dot** on the doctor's
patient row — never shown to the patient.

## Elderly-first design (hard rules)

72dp+ tap targets · full-width buttons · single tap only (no long-press / swipe /
double-tap) · text ≥ 24sp (games 40sp) · no timers / countdowns · gentle feedback
(green check / "let's try again", never a harsh red or buzzer) · calm high-contrast
palette · patient screens don't scroll. A **frustration protocol** slips into Calm
mode after 3 wrong in a row or ~30s idle.

## Multilingual

UI localized via Flutter l10n: English, Hindi, Assamese, Bengali, Bodo,
Manipuri/Meitei. The patient's language comes from their profile; TTS follows it.
(Hindi/Bengali fully translated; Assamese partial; Bodo/Manipuri fall back to
English pending translation.)

## Privacy

Only **anonymized** data (game name, level, numeric scores) is ever sent to the
optional AI. Patient name, photos, and voice never leave the device. Firebase
client config is committed intentionally (secured by rules, not by hiding);
real AI keys live in a gitignored `.env`.
