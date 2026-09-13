import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Logical buttons on the NAWAL 16-key BLE remote.
///
/// The firmware (see `hardware/nawal_remote.ino`) sends exactly one ASCII byte
/// per press; [_decode] turns that byte into one of these. This enum is the
/// app half of the firmware↔app contract — if the firmware key map changes,
/// change [_decode] to match.
enum RemoteButton {
  one, two, three, four, five, six, seven, eight, nine,
  hint, pageUp, pageDown, back, sound, next, call, unknown,
}

RemoteButton _decode(String c) => const <String, RemoteButton>{
      '1': RemoteButton.one, '2': RemoteButton.two, '3': RemoteButton.three,
      '4': RemoteButton.four, '5': RemoteButton.five, '6': RemoteButton.six,
      '7': RemoteButton.seven, '8': RemoteButton.eight, '9': RemoteButton.nine,
      'H': RemoteButton.hint, 'U': RemoteButton.pageUp, 'D': RemoteButton.pageDown,
      'B': RemoteButton.back, 'S': RemoteButton.sound,
      'N': RemoteButton.next, 'C': RemoteButton.call,
    }[c] ??
    RemoteButton.unknown;

/// If a [RemoteButton] is a numbered option (1-9), its zero-based option index;
/// otherwise null. `RemoteButton.one` -> 0, ... `RemoteButton.nine` -> 8.
int? remoteButtonOptionIndex(RemoteButton b) {
  const List<RemoteButton> numbers = <RemoteButton>[
    RemoteButton.one, RemoteButton.two, RemoteButton.three,
    RemoteButton.four, RemoteButton.five, RemoteButton.six,
    RemoteButton.seven, RemoteButton.eight, RemoteButton.nine,
  ];
  final int i = numbers.indexOf(b);
  return i < 0 ? null : i;
}

/// High-level connection state, surfaced to the UI.
enum RemoteStatus { off, scanning, connected }

/// App-wide singleton that owns the single BLE link to the NAWAL remote.
///
/// Started once at launch ([start]); games and screens subscribe to [buttons]
/// and [status]. Everything is a no-op on web (BLE is Android-only) so the same
/// widgets compile and run on the web build without change.
class NawalRemote {
  NawalRemote._();
  static final NawalRemote instance = NawalRemote._();

  static const String _service = 'a1c00000-1b2c-4f3d-8e9a-0123456789ab';
  static const String _char = 'a1c00001-1b2c-4f3d-8e9a-0123456789ab';
  static const String _name = 'NAWAL Remote';

  final StreamController<RemoteButton> _buttons =
      StreamController<RemoteButton>.broadcast();
  final ValueNotifier<RemoteStatus> statusNotifier =
      ValueNotifier<RemoteStatus>(RemoteStatus.off);

  /// Broadcast stream of button presses. Multiple screens may listen at once.
  Stream<RemoteButton> get buttons => _buttons.stream;

  /// Convenience: current connection state as a bool.
  bool get isConnected => statusNotifier.value == RemoteStatus.connected;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _valSub;
  bool _started = false;
  bool _disposing = false;

  /// True on platforms where the remote can work at all.
  bool get isSupported => !kIsWeb;

  /// Begin scanning + auto-connecting. Safe to call more than once.
  Future<void> start() async {
    if (!isSupported || _started) return;
    _started = true;
    _disposing = false;
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _started = false;
        return;
      }
      await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      // Wait until the adapter is on (user may enable it later).
      await FlutterBluePlus.adapterState
          .firstWhere((BluetoothAdapterState s) => s == BluetoothAdapterState.on);
      _scan();
    } catch (e) {
      debugPrint('NawalRemote.start error: $e');
      _started = false;
    }
  }

  void _scan() {
    if (_disposing) return;
    statusNotifier.value = RemoteStatus.scanning;
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
      for (final ScanResult r in results) {
        if (r.device.platformName == _name) {
          FlutterBluePlus.stopScan();
          _connect(r.device);
          break;
        }
      }
    });
    FlutterBluePlus.startScan(
      withServices: <Guid>[Guid(_service)],
      timeout: const Duration(seconds: 15),
    ).catchError((_) {});
  }

  Future<void> _connect(BluetoothDevice d) async {
    _connSub?.cancel();
    _connSub = d.connectionState.listen((BluetoothConnectionState st) {
      final bool up = st == BluetoothConnectionState.connected;
      statusNotifier.value = up ? RemoteStatus.connected : RemoteStatus.scanning;
      if (st == BluetoothConnectionState.disconnected && !_disposing) {
        _scan(); // auto-reconnect
      }
    });
    try {
      await d.connect();
      for (final BluetoothService s in await d.discoverServices()) {
        if (s.uuid != Guid(_service)) continue;
        for (final BluetoothCharacteristic c in s.characteristics) {
          if (c.uuid != Guid(_char)) continue;
          await c.setNotifyValue(true);
          _valSub?.cancel();
          _valSub = c.onValueReceived.listen((List<int> bytes) {
            if (bytes.isEmpty) return;
            _buttons.add(_decode(String.fromCharCode(bytes.first)));
          });
        }
      }
    } catch (e) {
      debugPrint('NawalRemote.connect error: $e');
      if (!_disposing) _scan();
    }
  }

  /// Stop scanning/connection but keep the singleton alive (call [start] again
  /// to resume). Used when leaving a screen that owned the connection intent.
  Future<void> stop() async {
    _disposing = true;
    await _scanSub?.cancel();
    await _connSub?.cancel();
    await _valSub?.cancel();
    _scanSub = null;
    _connSub = null;
    _valSub = null;
    _started = false;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    statusNotifier.value = RemoteStatus.off;
  }
}
