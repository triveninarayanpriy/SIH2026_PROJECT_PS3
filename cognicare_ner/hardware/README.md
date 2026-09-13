# NAWAL Remote — hardware

A 16-button BLE controller (ESP32) that drives the patient's screen, fully
offline (no Wi-Fi). One button press → one ASCII byte over a BLE notify → the
Flutter app acts. Games are always playable by touch; the remote is additive.

## Firmware↔app contract (keep in sync)

| Button        | Grid  | Byte | App action (`RemoteButton`)        |
|---------------|-------|------|------------------------------------|
| 1–9           | R1–R3 | `1`–`9` | Select on-screen option 1–9    |
| Hint (eye)    | R1C4  | `H`  | `hint` — reveal a clue             |
| Page ▲        | R2C4  | `U`  | `pageUp` — previous page of choices|
| Page ▼        | R3C4  | `D`  | `pageDown` — next page of choices  |
| Back / Repeat | R4C1  | `B`  | `back` — repeat the prompt         |
| Sound         | R4C2  | `S`  | `sound` — replay audio / voice     |
| Next          | R4C3  | `N`  | `next` — advance to next step      |
| Call          | R4C4  | `C`  | `call` — fire caregiver SOS alert  |

BLE identifiers (must match `lib/core/services/nawal_remote.dart`):

- Service UUID: `a1c00000-1b2c-4f3d-8e9a-0123456789ab`
- Button characteristic (notify): `a1c00001-1b2c-4f3d-8e9a-0123456789ab`
- Advertised name: `NAWAL Remote`

## Wiring (4×4 matrix on 8 GPIO)

| Line  | Buttons                     | GPIO |
|-------|-----------------------------|------|
| Row 1 | 1 · 2 · 3 · Hint            | 13   |
| Row 2 | 4 · 5 · 6 · Page▲           | 14   |
| Row 3 | 7 · 8 · 9 · Page▼           | 27   |
| Row 4 | Back · Sound · Next · Call  | 26   |
| Col 1 | 1 · 4 · 7 · Back            | 32   |
| Col 2 | 2 · 5 · 8 · Sound           | 33   |
| Col 3 | 3 · 6 · 9 · Next            | 25   |
| Col 4 | Hint · Page▲ · Page▼ · Call | 4    |

No external resistors — the firmware enables internal pull-ups on the columns.
Power the ESP32 from a USB power bank for the demo (add 18650 + TP4056 + MT3608
set to 5.0 V for a self-contained battery build).

## Flashing (Arduino IDE)

1. **Boards:** File → Preferences → add
   `https://espressif.github.io/arduino-esp32/package_esp32_index.json`, then
   Boards Manager → install **esp32 by Espressif**.
2. **Library:** Manage Libraries → install **Keypad** (Mark Stanley, Alexander Brevig).
3. **Board:** Tools → Board → **ESP32 Dev Module**, pick the COM port.
4. **Upload** `nawal_remote.ino`. If it stalls at "Connecting…", hold **BOOT**.
5. **Verify:** Serial Monitor @ 115200 shows `advertising…`, then `Sent: N` per
   press. Before the app exists, test with the **nRF Connect** phone app.

## App side

Already wired: `lib/core/services/nawal_remote.dart` scans, connects,
auto-reconnects, and streams `RemoteButton`s; `GameShell` routes them; the
caregiver hub → **NAWAL Remote** screen shows live status + the button map.
BLE is Android-only — the whole path is a no-op on the web build. Test on a
real Android device (BLE does not work on emulators) and accept the Bluetooth
permission prompt on first run.
