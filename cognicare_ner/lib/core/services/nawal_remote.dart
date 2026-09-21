import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Logical buttons on the NAWAL 16-key BLE remote.
///
/// The firmware (hardware/nawal_remote.ino) sends exactly one ASCII byte per
/// press; [_decode] turns it into one of these. Keep this in sync with the
/// firmware key map.
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

/// If a [RemoteButton] is a numbered option (1-9), its zero-based option index.
int? remoteButtonOptionIndex(RemoteButton b) {
  const List<RemoteButton> numbers = <RemoteButton>[
    RemoteButton.one, RemoteButton.two, RemoteButton.three,
    RemoteButton.four, RemoteButton.five, RemoteButton.six,
    RemoteButton.seven, RemoteButton.eight, RemoteButton.nine,
  ];
  final int i = numbers.indexOf(b);
  return i < 0 ? null : i;
}

enum RemoteStatus { off, scanning, connecting, connected }

/// App-wide singleton owning the single BLE link to the NAWAL remote.
///
/// Design rules that keep it stable (the old version crashed/lagged by ignoring
/// these):
///  * NEVER touch Bluetooth at app launch — only on an explicit user action.
///  * ALWAYS request runtime permission before scanning (Android 12+ throws
///    otherwise).
///  * Scan WITHOUT a service filter and match by device name — an ESP32's
///    advertisement often omits the service UUID, so a filtered scan finds
///    nothing.
///  * Wrap every plugin call in try/catch and surface a human error message.
///  * No-op on web.
class NawalRemote {
  NawalRemote._();
  static final NawalRemote instance = NawalRemote._();

  static const String kServiceUuid = 'a1c00000-1b2c-4f3d-8e9a-0123456789ab';
  static const String kCharUuid = 'a1c00001-1b2c-4f3d-8e9a-0123456789ab';
  static const String kDeviceName = 'NAWAL Remote';

  final StreamController<RemoteButton> _buttons =
      StreamController<RemoteButton>.broadcast();

  /// Broadcast stream of button presses.
  Stream<RemoteButton> get buttons => _buttons.stream;

  final ValueNotifier<RemoteStatus> statusNotifier =
      ValueNotifier<RemoteStatus>(RemoteStatus.off);

  /// Last human-readable error/status hint for the UI (null when fine).
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  /// Devices seen during the current scan (for the picker UI).
  final ValueNotifier<List<ScanResult>> devicesNotifier =
      ValueNotifier<List<ScanResult>>(const <ScanResult>[]);

  bool get isSupported => !kIsWeb;
  bool get isConnected => statusNotifier.value == RemoteStatus.connected;

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _valueSub;
  bool _wantConnected = false;
  bool _busy = false;

  void _setStatus(RemoteStatus s) => statusNotifier.value = s;
  void _setError(String? e) => errorNotifier.value = e;

  /// Request the runtime permissions BLE needs. Returns true when usable.
  Future<bool> ensurePermissions() async {
    if (!isSupported) return false;
    try {
      final Map<Permission, PermissionStatus> res = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse, // needed for BLE scan on Android 11 & below
      ].request();
      final bool connectOk =
          res[Permission.bluetoothConnect]?.isGranted ?? false;
      final bool scanOk = (res[Permission.bluetoothScan]?.isGranted ?? false) ||
          (res[Permission.locationWhenInUse]?.isGranted ?? false);
      return connectOk && scanOk;
    } catch (e) {
      debugPrint('NawalRemote.permissions error: $e');
      return false;
    }
  }

  /// Kept for older callers; delegates to [connect].
  Future<void> start() => connect();

  /// Begin the connect flow — user gesture only.
  Future<void> connect() async {
    if (!isSupported || _busy) return;
    _busy = true;
    _wantConnected = true;
    _setError(null);
    try {
      if (await FlutterBluePlus.isSupported == false) {
        _setError('This device does not support Bluetooth Low Energy.');
        _setStatus(RemoteStatus.off);
        return;
      }
      final bool ok = await ensurePermissions();
      if (!ok) {
        _setError('Bluetooth permission is required. Please allow it (or enable it in Settings) and try again.');
        _setStatus(RemoteStatus.off);
        return;
      }
      final BluetoothAdapterState adapter =
          await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 4),
        onTimeout: () => FlutterBluePlus.adapterStateNow,
      );
      if (adapter != BluetoothAdapterState.on) {
        _setError('Please turn Bluetooth ON, then tap Connect again.');
        _setStatus(RemoteStatus.off);
        return;
      }
      await _startScan();
    } catch (e) {
      debugPrint('NawalRemote.connect error: $e');
      _setError('Could not start Bluetooth. Try again.');
      _setStatus(RemoteStatus.off);
    } finally {
      _busy = false;
    }
  }

  Future<void> _startScan() async {
    _setStatus(RemoteStatus.scanning);
    devicesNotifier.value = const <ScanResult>[];
    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
      // Surface named devices (or the NAWAL one) to the picker, sorted by RSSI.
      final List<ScanResult> named = results
          .where((r) => _nameOf(r).isNotEmpty)
          .toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      devicesNotifier.value = named;
      for (final ScanResult r in results) {
        if (_nameOf(r) == kDeviceName) {
          _connectTo(r.device);
          break;
        }
      }
    }, onError: (Object e) {
      debugPrint('NawalRemote.scan error: $e');
    });
    try {
      // No service filter → the remote shows up regardless of its advert.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
      // If the scan finished and we still aren't connected, drop to off.
      if (_wantConnected && statusNotifier.value == RemoteStatus.scanning) {
        _setStatus(RemoteStatus.off);
        if (errorNotifier.value == null) {
          _setError('“NAWAL Remote” not found. Make sure it is powered on and nearby, then try again.');
        }
      }
    } catch (e) {
      debugPrint('NawalRemote.startScan error: $e');
      _setError('Could not start scanning. Try again.');
      _setStatus(RemoteStatus.off);
    }
  }

  String _nameOf(ScanResult r) {
    if (r.device.platformName.isNotEmpty) return r.device.platformName;
    return r.advertisementData.advName;
  }

  /// Connect to a specific device (auto-picked or user-picked).
  Future<void> connectTo(BluetoothDevice device) => _connectTo(device);

  Future<void> _connectTo(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _setStatus(RemoteStatus.connecting);
    _setError(null);
    _device = device;
    await _connSub?.cancel();
    _connSub = device.connectionState.listen((BluetoothConnectionState st) {
      if (st == BluetoothConnectionState.connected) {
        _setStatus(RemoteStatus.connected);
      } else if (st == BluetoothConnectionState.disconnected) {
        _valueSub?.cancel();
        if (_wantConnected) {
          _setStatus(RemoteStatus.scanning);
          _startScan(); // auto-reconnect
        } else {
          _setStatus(RemoteStatus.off);
        }
      }
    });
    try {
      await device.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      final List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? target;
      for (final BluetoothService s in services) {
        for (final BluetoothCharacteristic c in s.characteristics) {
          if (c.uuid.str.toLowerCase() == kCharUuid.toLowerCase()) {
            target = c;
          }
        }
      }
      target ??= _firstNotifiable(services);
      if (target == null) {
        _setError('Connected, but no button channel was found on the remote.');
        return;
      }
      await target.setNotifyValue(true);
      await _valueSub?.cancel();
      _valueSub = target.onValueReceived.listen((List<int> bytes) {
        if (bytes.isEmpty) return;
        _buttons.add(_decode(String.fromCharCode(bytes.first)));
      });
    } catch (e) {
      debugPrint('NawalRemote.connectTo error: $e');
      _setError('Connection failed. Move closer and try again.');
      if (_wantConnected) {
        _setStatus(RemoteStatus.scanning);
        _startScan();
      } else {
        _setStatus(RemoteStatus.off);
      }
    }
  }

  BluetoothCharacteristic? _firstNotifiable(List<BluetoothService> services) {
    for (final BluetoothService s in services) {
      for (final BluetoothCharacteristic c in s.characteristics) {
        if (c.properties.notify || c.properties.indicate) return c;
      }
    }
    return null;
  }

  /// Stop everything (user tapped disconnect / left the flow).
  Future<void> disconnect() async {
    _wantConnected = false;
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    await _scanSub?.cancel();
    await _valueSub?.cancel();
    try { await _device?.disconnect(); } catch (_) {}
    _device = null;
    devicesNotifier.value = const <ScanResult>[];
    _setStatus(RemoteStatus.off);
  }

  /// Alias kept for older callers.
  Future<void> stop() => disconnect();
}
