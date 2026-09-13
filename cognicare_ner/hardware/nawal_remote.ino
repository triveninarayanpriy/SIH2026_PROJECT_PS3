/*  NAWAL Remote — ESP32 BLE firmware
 *  16-button 4x4 matrix -> one byte per press, sent to the Flutter app.
 *  Board:     ESP32 Dev Module        Libraries: Keypad (Mark Stanley)
 *  Built-in:  ESP32 BLE (BLEDevice.h) ships with the ESP32 core
 *
 *  CONTRACT: the byte each key sends here MUST match _decode() in the app
 *  (lib/core/services/nawal_remote.dart). Change one, change both.
 */
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Keypad.h>

// ---- Custom BLE IDs — must match the app exactly ----
#define SERVICE_UUID      "a1c00000-1b2c-4f3d-8e9a-0123456789ab"
#define BUTTON_CHAR_UUID  "a1c00001-1b2c-4f3d-8e9a-0123456789ab"
#define DEVICE_NAME       "NAWAL Remote"

BLECharacteristic *btnChar;
bool connected = false;

// ---- 4x4 matrix: each cell is one button; the char is what the app reads ----
const byte ROWS = 4, COLS = 4;
char keys[ROWS][COLS] = {
  {'1','2','3','H'},   // H = Hint (eye)
  {'4','5','6','U'},   // U = Page Up
  {'7','8','9','D'},   // D = Page Down
  {'B','S','N','C'}    // Back  Sound  Next  Call
};
byte rowPins[ROWS] = {13,14,27,26};
byte colPins[COLS] = {32,33,25,4};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// ---- Re-advertise automatically when the tablet disconnects ----
class ServerCB : public BLEServerCallbacks {
  void onConnect(BLEServer *s)    { connected = true; }
  void onDisconnect(BLEServer *s) { connected = false; s->getAdvertising()->start(); }
};

void setup() {
  Serial.begin(115200);
  keypad.setDebounceTime(40);

  BLEDevice::init(DEVICE_NAME);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCB());

  BLEService *svc = server->createService(SERVICE_UUID);
  btnChar = svc->createCharacteristic(BUTTON_CHAR_UUID,
              BLECharacteristic::PROPERTY_NOTIFY);
  btnChar->addDescriptor(new BLE2902());   // lets the app subscribe
  svc->start();

  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("NAWAL Remote advertising...");
}

void loop() {
  char key = keypad.getKey();          // non-blocking
  if (key && connected) {
    uint8_t b = (uint8_t)key;
    btnChar->setValue(&b, 1);           // send the single byte
    btnChar->notify();
    Serial.printf("Sent: %c\n", key);
  }
}
