# NAWAL — नवल

**Giving a new life to somebody.** An offline-first, free dementia-care companion
built for SIH 2026 (PS 26003), tuned for India's North Eastern Region.

One Flutter codebase, three roles (Patient · Caregiver · Doctor), on Android and
Web. Live demo: **https://cognicare-ner.web.app**

## What it does

- **Patient** — big, calm, single-tap games with auto-spoken prompts, gentle
  feedback (no buzzers), a frustration protocol that slips into Calm mode, a
  welcome photo/voice/video, reminders, and voice answers.
- **Caregiver** — add family photos & voices, set reminders, personalise the
  games, and a warm dashboard: friendly status, this-week-at-a-glance, an
  AI weekly note, a progress trend, and an interactive daily-care checklist with
  a weekly completion ring.
- **Doctor** — a clinical view: triage pills (green/amber/red), a composite
  cognitive score with the anomaly change-point, a per-domain radar, per-domain
  trends, alert history, a sessions table, a 7-day adherence strip, an AI
  clinical summary, and a downloadable weekly PDF.

Switch roles anytime with the bottom **Switch** button.

## Games

Seven games, all on one shared shell (auto-audio, gentle feedback, voice + remote
input, adaptive difficulty):

1. **What comes next?** — pattern/attention
2. **Who is this?** — family faces / memory
3. **Whose voice?** — family voices / listening
4. **Complete the name** — family name completion / language *(new)*
5. **Do you remember?** — milestone & life-events recall / episodic memory *(new)*
6. **What comes next? (routine)** — daily routine sequencing / executive *(new)*
7. **What is this?** — cultural & personal object identification / attention *(new)*

The four new games are **caregiver-authored**: Caregiver Hub → **Personalise
Games** (memories, routine steps, objects); name completion reuses Family Media.

## AI features (free tier: Groq → Gemini fallback)

Adaptive difficulty · anomaly / cognitive-drop detection · difficulty notes ·
speech transcription · TTS prompts · **AI caregiver/clinician weekly notes**.
Only anonymised numbers leave the device (never name, photo, or voice), and every
feature degrades to an on-device fallback so nothing needs the network.

## NAWAL Remote (ESP32 · BLE · offline)

A 16-button Bluetooth remote drives the patient's screen — number keys select
answers, Sound/Back repeat, Hint nudges, Call raises a caregiver SOS. It's
**additive**: every game is fully playable by touch, and the whole BLE path is a
no-op on web. Firmware, wiring, and the firmware↔app byte contract live in
[`hardware/`](hardware/README.md); the app service is
`lib/core/services/nawal_remote.dart`.

## Run it

```bash
flutter pub get
flutter run                                   # your device/emulator
flutter run --dart-define=DEMO=true           # seeded demo (Kamala Devi)
```

Build & deploy:

```bash
flutter build web --release --dart-define=DEMO=true
firebase deploy --only hosting
flutter build apk --release                   # Android (needed for the remote)
```

## Architecture

- **Offline-first**: Hive local store, write-through + a Firestore sync queue
  that drains when online (`connectivity_plus`).
- **Free forever**: Firebase Spark only — Auth, Firestore, Hosting. No paid
  Storage/Blaze. Media stays on-device; caregiver content is JSON in Hive.
- **Web-safe media**: `lib/core/widgets/platform_media.dart` routes
  http/blob/asset sources safely and only touches `dart:io` off-web.
- **Localization**: 10 NER languages (en, hi, as, bn, brx, mni, ne, lus, kha,
  nag) via gen-l10n, with TTS locale mapping.

`--dart-define=DEMO=true` (or a long-press on the login title) seeds patient
**Kamala Devi** (74, stage 2, Assam) with a gentle decline that fires a memory
alert — the whole three-role demo runs from one populated device, offline.
