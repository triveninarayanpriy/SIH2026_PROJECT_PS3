# DEMO_SCRIPT — CogniCare NER (≈ 90 seconds)

**Setup (before recording):** enable Firebase Auth + Firestore (see
[RUN.md](RUN.md)), then launch the fully-seeded app:

```bash
cd cognicare_ner
flutter run -t lib/main.dart --dart-define=DEMO=true -d chrome
```

This seeds patient **Kamala Devi** with family photos/voices, reminders, ~17
game sessions (nice trends + a memory decline), and a fired drop-alert. In demo
mode caregiver/doctor skip login. Use the bottom-left **"Role"** button to switch.

---

## Tap-by-tap

| Time | Action | What it shows |
|---|---|---|
| 0:00 | App opens on **"Who is using this device?"** → tap **Patient** | Role picker |
| 0:06 | Patient Home: "Hello, Kamala" + 4 big buttons | **Elderly-first UI** (a) |
| 0:12 | Tap **"What comes next?"** → tap the correct tile | Pattern game, huge single-tap tiles, **"Very good!"** + chime (b) |
| 0:22 | Finish the 5 rounds → **reward screen** (stars + family photo) | Reward, difficulty auto-adjusts (c) |
| 0:30 | Back → **"Who is this?"** → tap the right name | Family-face recognition with real photos (d) |
| 0:38 | Back → **"Relax"** | Calm mode: photo slideshow + music (d) |
| 0:46 | **Offline test:** turn on airplane mode → play one round → back on the game the sync chip reads **Offline** → turn airplane **off** | Plays & saves **fully offline**, then the queue drains (e) |
| 1:04 | **Role** → **Caregiver** → progress dashboard | Per-domain trends (7/30d), games this week, difficulty, and the **gentle drop-alert banner** "consider consulting a doctor" (f, g) |
| 1:20 | **Role** → **Doctor** → patient list (Kamala has a **red dot**) → tap her | Read-only clinician view (h) |
| 1:26 | Doctor detail: 30-day trend, sessions table, **Alert history** ("possible progression") → tap **Weekly report** | Printable one-page summary for a distant clinic (g, h) |
| 1:30 | End | — |

> **Backup for the offline beat (no OS airplane needed):** Caregiver →
> *Developer: theme preview* → **Offline sync — Airplane test**: tap "Queue a
> game result" a few times (watch the number grow), then "Sync now" → it drains
> to 0. The same screen has **Seed declining data** (fires an alert on demand)
> and **Test AI**.

---

## Shot list — one screenshot per capability

> Map these to the official PS letters; the app covers the PS3 dementia-care
> capabilities as follows.

| # | Capability | Screen to capture |
|---|---|---|
| a | Accessible elderly-first UI | Patient Home (big buttons, large text) |
| b | Cognitive games (multi-domain) | Pattern / Family-face / Voice game mid-round |
| c | Adaptive difficulty (AI) | Reward screen + caregiver "Current difficulty" card |
| d | Familiar-voice & photo personalization | "Who is this?" with family photos · Calm mode slideshow |
| e | Offline-first operation | Game played with the **Offline** sync chip showing |
| f | Caregiver monitoring / daily care | Caregiver **progress dashboard** (trend charts) |
| g | Early-warning anomaly detection | Caregiver **alert banner** + doctor row **red dot** |
| h | Clinician remote dashboard + report | Doctor **patient detail** + the printed **Weekly report** |

Cross-cutting: **multilingual** (set the patient's language to Hindi in the
caregiver "Add patient" form to capture a Hindi patient screen).

---

## One-line pitch

> "An offline-first, elderly-friendly app where dementia patients play calm
> cognitive games in their own language, families set it up and hear a gentle
> early warning when memory slips, and doctors review the trend remotely — all
> free, all working without internet."
