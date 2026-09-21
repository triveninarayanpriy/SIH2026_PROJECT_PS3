import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Standalone BLE diagnostic screen for the NAWAL ESP32 remote.
///
/// Purpose (NOT wired into the games yet):
///   SCAN  →  find "NAWAL Remote"  →  CONNECT  →  DISCOVER  →  SUBSCRIBE  →  see "S"
///
/// It scans WITHOUT a service filter on purpose — if the ESP32's advertising
/// packet doesn't carry the service UUID, a filtered scan silently finds
/// nothing. Here you see every BLE device, so you can confirm the remote shows
/// up, then tap it to connect and watch the bytes arrive live.
class BleTestScreen extends StatefulWidget {
  const BleTestScreen({super.key});

  // Must match the firmware (hardware/nawal_remote.ino).
  static const String kServiceUuid = 'a1c00000-1b2c-4f3d-8e9a-0123456789ab';
  static const String kCharUuid = 'a1c00001-1b2c-4f3d-8e9a-0123456789ab';
  static const String kDeviceName = 'NAWAL Remote';

  @override
  State<BleTestScreen> createState() => _BleTestScreenState();
}

class _BleTestScreenState extends State<BleTestScreen> {
  final List<String> _log = <String>[];
  final Map<String, ScanResult> _results = <String, ScanResult>{};

  BluetoothAdapterState _adapter = BluetoothAdapterState.unknown;
  bool _scanning = false;
  BluetoothDevice? _connected;
  String _lastByte = '—';
  int _pressCount = 0;

  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _valueSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _init();
  }

  void _log0(String m) {
    debugPrint('[BLE] $m');
    if (!mounted) return;
    setState(() {
      _log.insert(0, '${TimeOfDay.now().format(context)}  $m');
      if (_log.length > 200) _log.removeLast();
    });
  }

  Future<void> _init() async {
    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      if (mounted) setState(() => _adapter = s);
      _log0('Adapter state: $s');
    });
    _isScanningSub = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => _scanning = s);
    });
    try {
      final bool supported = await FlutterBluePlus.isSupported;
      _log0('Bluetooth supported: $supported');
    } catch (e) {
      _log0('isSupported error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final Map<Permission, PermissionStatus> res = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    res.forEach((p, s) => _log0('Permission $p = $s'));
  }

  Future<void> _startScan() async {
    _results.clear();
    setState(() {});
    await _requestPermissions();
    try {
      if (_adapter != BluetoothAdapterState.on) {
        _log0('Adapter is not ON ($_adapter). Turn on Bluetooth.');
        // Try to nudge it on Android.
        try { await FlutterBluePlus.turnOn(); } catch (_) {}
      }
      _log0('Starting scan (no service filter, 12s)…');
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
        for (final ScanResult r in results) {
          final String id = r.device.remoteId.str;
          final bool isNew = !_results.containsKey(id);
          _results[id] = r;
          if (isNew) {
            final String name = r.device.platformName.isNotEmpty
                ? r.device.platformName
                : (r.advertisementData.advName.isNotEmpty
                    ? r.advertisementData.advName
                    : '(no name)');
            _log0('Found: $name  [$id]  rssi=${r.rssi}');
          }
        }
        if (mounted) setState(() {});
      }, onError: (e) => _log0('scanResults error: $e'));

      // No withServices filter → see everything.
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    } catch (e) {
      _log0('startScan error: $e');
    }
  }

  Future<void> _stopScan() async {
    try { await FlutterBluePlus.stopScan(); } catch (_) {}
    _log0('Scan stopped.');
  }

  Future<void> _connect(BluetoothDevice device) async {
    await _stopScan();
    final String label = device.platformName.isEmpty ? device.remoteId.str : device.platformName;
    _log0('Connecting to $label…');
    _connSub?.cancel();
    _connSub = device.connectionState.listen((BluetoothConnectionState st) {
      _log0('Connection state: $st');
      if (st == BluetoothConnectionState.connected) {
        if (mounted) setState(() => _connected = device);
      } else if (st == BluetoothConnectionState.disconnected) {
        if (mounted) setState(() => _connected = null);
      }
    });
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      _log0('Connected. Discovering services…');
      final List<BluetoothService> services = await device.discoverServices();
      _log0('Found ${services.length} service(s).');
      BluetoothCharacteristic? target;
      for (final BluetoothService s in services) {
        _log0('Service ${s.uuid.str}');
        for (final BluetoothCharacteristic c in s.characteristics) {
          final p = c.properties;
          _log0('  char ${c.uuid.str}  notify=${p.notify} indicate=${p.indicate} read=${p.read}');
          if (c.uuid.str.toLowerCase() == BleTestScreen.kCharUuid.toLowerCase()) {
            target = c;
          }
        }
      }
      // Prefer the exact button characteristic; else the first notifiable one.
      target ??= _firstNotifiable(services);
      if (target == null) {
        _log0('No notifiable characteristic found. Cannot subscribe.');
        return;
      }
      _log0('Subscribing to ${target.uuid.str}…');
      await target.setNotifyValue(true);
      _valueSub?.cancel();
      _valueSub = target.onValueReceived.listen((List<int> bytes) {
        if (bytes.isEmpty) return;
        final String ascii = String.fromCharCode(bytes.first);
        _pressCount++;
        if (mounted) setState(() => _lastByte = ascii);
        _log0('◀ received byte: "$ascii"  (raw=$bytes)');
      });
      _log0('Subscribed. Press a button on the remote — you should see "S", "N", "1"…');
    } catch (e) {
      _log0('connect/discover error: $e');
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

  Future<void> _disconnect() async {
    try { await _connected?.disconnect(); } catch (_) {}
    _valueSub?.cancel();
    _log0('Disconnected.');
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _connSub?.cancel();
    _valueSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('BLE Test')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Bluetooth works only on the Android app, not on the web.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final List<ScanResult> sorted = _results.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Test — NAWAL Remote'),
        actions: <Widget>[
          if (_connected != null)
            IconButton(
              tooltip: 'Disconnect',
              icon: const Icon(Icons.link_off_rounded),
              onPressed: _disconnect,
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            color: const Color(0xFF1A3C5A),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Adapter: ${_adapter.name}   ·   ${_connected != null ? "CONNECTED" : (_scanning ? "SCANNING…" : "idle")}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    const Text('Last byte: ', style: TextStyle(color: Colors.white70)),
                    Text('"$_lastByte"',
                        style: const TextStyle(color: Color(0xFF92D6EF), fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Text('presses: $_pressCount', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _scanning ? _stopScan : _startScan,
                    icon: Icon(_scanning ? Icons.stop_rounded : Icons.bluetooth_searching_rounded),
                    label: Text(_scanning ? 'Stop scan' : 'Scan (all devices)'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _requestPermissions, child: const Text('Permissions')),
              ],
            ),
          ),
          // Found devices
          SizedBox(
            height: 190,
            child: sorted.isEmpty
                ? const Center(child: Text('No devices yet. Tap “Scan”. Make sure the ESP32 is powered and advertising.'))
                : ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final ScanResult r = sorted[i];
                      final String name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : (r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : '(no name)');
                      final bool isNawal = name == BleTestScreen.kDeviceName;
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.bluetooth,
                            color: isNawal ? const Color(0xFF0D5C75) : Colors.grey),
                        title: Text(name,
                            style: TextStyle(fontWeight: isNawal ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text('${r.device.remoteId.str}   rssi ${r.rssi}'),
                        trailing: FilledButton(
                          onPressed: () => _connect(r.device),
                          child: const Text('Connect'),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Align(alignment: Alignment.centerLeft, child: Text('Log', style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFF0E1620),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (context, i) => Text(
                  _log[i],
                  style: const TextStyle(color: Color(0xFFB9E5F4), fontFamily: 'monospace', fontSize: 11.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
