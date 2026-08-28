# RUN — CogniCare NER

All commands run from the Flutter project folder:

```bash
cd cognicare_ner
flutter pub get
```

## One-time Firebase setup (free, no credit card)

The app runs offline without this, but caregiver/doctor login and cloud sync need
two console toggles on the **Spark** plan:

1. **Authentication** → enable **Anonymous** + **Email/Password**
   `https://console.firebase.google.com/project/cognicare-ner/authentication/providers`
2. **Firestore** → **Create database** → region `asia-south1` → **test mode**
   `https://console.firebase.google.com/project/cognicare-ner/firestore`

(`lib/firebase_options.dart` and `google-services.json` are already generated.)

## Run each role

**Unified app (recommended for the demo)** — role picker + one-tap switch:

```bash
flutter run -t lib/main.dart -d chrome
```

**Locked per-role builds:**

```bash
flutter run -t lib/main_patient.dart   --dart-define=ROLE=patient   -d chrome
flutter run -t lib/main_caregiver.dart --dart-define=ROLE=caregiver -d chrome
flutter run -t lib/main_doctor.dart    --dart-define=ROLE=doctor     -d chrome
```

The **doctor** dashboard is web (`-d chrome`/`-d edge`). For Android use
`-d <device-id>` (see `flutter devices`). Build web: `flutter build web -t lib/main.dart`.

## Demo mode (fully-populated, no manual setup)

Seeds patient "Kamala Devi" with family photos/voices, reminders, ~17 game
sessions (nice trends + a memory-decline alert), and populates the doctor
dashboard. In demo mode caregiver/doctor **skip login** so every screen is
screenshot-ready.

```bash
flutter run -t lib/main.dart --dart-define=DEMO=true -d chrome
```

Or, at runtime: on the **caregiver/doctor sign-in** screen, **long-press the
title** to load demo data.

## AI keys (optional — Tier-2 difficulty notes & Whisper STT)

Paste your two **free** keys into **`cognicare_ner/.env`** (gitignored):

```
GROQ_API_KEY=your_groq_key_here
GEMINI_API_KEY=your_gemini_key_here
```

- Groq (free): https://console.groq.com/keys
- Gemini (free): https://aistudio.google.com/app/apikey

Hot-restart after pasting. Test it: caregiver → **Developer: theme preview** →
**AI (Tier 2)** → **Test AI**. Without keys the app uses the on-device rule.
Note: browser calls to Groq may be blocked by CORS — the Gemini fallback and
Android builds are unaffected.

## Verify

```bash
flutter analyze     # clean
flutter test        # 14 pass
```
