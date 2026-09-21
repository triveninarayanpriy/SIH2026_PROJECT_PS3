import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/services/nawal_remote.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../dev/ble_test_screen.dart';

/// Pair, test, and use the NAWAL BLE remote. Bluetooth is Android-only; on web
/// this explains that the games are fully playable by touch.
class RemoteConnectScreen extends StatefulWidget {
  const RemoteConnectScreen({super.key});

  @override
  State<RemoteConnectScreen> createState() => _RemoteConnectScreenState();
}

class _RemoteConnectScreenState extends State<RemoteConnectScreen> {
  StreamSubscription<RemoteButton>? _sub;
  RemoteButton? _flash;
  Timer? _flashTimer;
  int _pressCount = 0;

  @override
  void initState() {
    super.initState();
    _sub = NawalRemote.instance.buttons.listen((RemoteButton b) {
      if (!mounted) return;
      setState(() {
        _flash = b;
        _pressCount++;
      });
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _flash = null);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  NawalRemote get _r => NawalRemote.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.skyBg,
      appBar: AppBar(title: const Text('NAWAL Remote')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: <Widget>[
              if (!_r.isSupported)
                _webNote()
              else ...<Widget>[
                _statusCard(),
                const SizedBox(height: 12),
                _errorBanner(),
                _actionButtons(),
                const SizedBox(height: 16),
                _devicePicker(),
                _remoteMock(),
                const SizedBox(height: 8),
                _diagnosticLink(),
              ],
              const SizedBox(height: 20),
              Text('What the buttons do', style: AppText.title().copyWith(fontSize: 20)),
              const SizedBox(height: 12),
              _legend(),
              const SizedBox(height: 16),
              _setupSteps(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Status ------------------------------------------------------------
  Widget _statusCard() {
    return ValueListenableBuilder<RemoteStatus>(
      valueListenable: _r.statusNotifier,
      builder: (context, RemoteStatus status, _) {
        final bool on = status == RemoteStatus.connected;
        final bool busy = status == RemoteStatus.scanning ||
            status == RemoteStatus.connecting;
        final Color color = on
            ? AppColors.success
            : (busy ? AppColors.gentleWarning : AppColors.textMuted);
        final String title = switch (status) {
          RemoteStatus.connected => 'Remote connected',
          RemoteStatus.connecting => 'Connecting…',
          RemoteStatus.scanning => 'Searching for the remote…',
          RemoteStatus.off => 'Remote not connected',
        };
        final String sub = on
            ? 'Press any button — it should light up below ($_pressCount so far).'
            : (busy
                ? 'Keep the remote powered on and close to this device.'
                : 'Tap “Connect remote” to begin.');
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 2),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (busy)
                      const SizedBox(
                          width: 46, height: 46, child: CircularProgressIndicator(strokeWidth: 2)),
                    Icon(on ? Icons.gamepad_rounded : Icons.bluetooth_rounded, size: 28, color: color),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppText.title().copyWith(fontSize: 18, color: color)),
                    const SizedBox(height: 2),
                    Text(sub, style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _errorBanner() {
    return ValueListenableBuilder<String?>(
      valueListenable: _r.errorNotifier,
      builder: (context, String? err, _) {
        if (err == null || err.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE7A6A6)),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.info_outline_rounded, color: Color(0xFFB23B3B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(err,
                    style: AppText.body().copyWith(fontSize: 13.5, color: const Color(0xFF7A2A2A))),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButtons() {
    return ValueListenableBuilder<RemoteStatus>(
      valueListenable: _r.statusNotifier,
      builder: (context, RemoteStatus status, _) {
        final bool on = status == RemoteStatus.connected;
        final bool busy = status == RemoteStatus.scanning ||
            status == RemoteStatus.connecting;
        if (on) {
          return OutlinedButton.icon(
            onPressed: () => _r.disconnect(),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Disconnect'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          );
        }
        if (busy) {
          return OutlinedButton.icon(
            onPressed: () => _r.disconnect(),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          );
        }
        return FilledButton.icon(
          onPressed: () => _r.connect(),
          icon: const Icon(Icons.bluetooth_searching_rounded),
          label: const Text('Connect remote'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        );
      },
    );
  }

  // ---- Device picker (shown while searching) -----------------------------
  Widget _devicePicker() {
    return ValueListenableBuilder<RemoteStatus>(
      valueListenable: _r.statusNotifier,
      builder: (context, RemoteStatus status, _) {
        if (status != RemoteStatus.scanning) return const SizedBox.shrink();
        return ValueListenableBuilder<List<ScanResult>>(
          valueListenable: _r.devicesNotifier,
          builder: (context, List<ScanResult> devices, _) {
            if (devices.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Nearby devices — tap “NAWAL Remote”',
                          style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 12)),
                    ),
                  ),
                  for (final ScanResult r in devices.take(8))
                    _deviceTile(r),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _deviceTile(ScanResult r) {
    final String name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : '(unknown)');
    final bool isNawal = name == NawalRemote.kDeviceName;
    return ListTile(
      dense: true,
      leading: Icon(Icons.bluetooth, color: isNawal ? AppColors.ink : AppColors.textMuted),
      title: Text(name,
          style: AppText.body().copyWith(fontWeight: isNawal ? FontWeight.bold : FontWeight.w400)),
      subtitle: Text('signal ${r.rssi} dBm',
          style: AppText.body(color: AppColors.textMuted).copyWith(fontSize: 11)),
      trailing: FilledButton(
        onPressed: () => _r.connectTo(r.device),
        style: FilledButton.styleFrom(
          backgroundColor: isNawal ? AppColors.ink : AppColors.textMuted,
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('Connect'),
      ),
    );
  }

  // ---- Visual remote (flashes on press) ----------------------------------
  Widget _remoteMock() {
    List<Widget> row(List<(String, RemoteButton)> keys) =>
        <Widget>[for (final (String, RemoteButton) k in keys) Expanded(child: _key(k.$1, k.$2))];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E2430), borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: <Widget>[
          Row(children: row(<(String, RemoteButton)>[
            ('1', RemoteButton.one), ('2', RemoteButton.two), ('3', RemoteButton.three), ('Hint', RemoteButton.hint),
          ])),
          Row(children: row(<(String, RemoteButton)>[
            ('4', RemoteButton.four), ('5', RemoteButton.five), ('6', RemoteButton.six), ('Page ▲', RemoteButton.pageUp),
          ])),
          Row(children: row(<(String, RemoteButton)>[
            ('7', RemoteButton.seven), ('8', RemoteButton.eight), ('9', RemoteButton.nine), ('Page ▼', RemoteButton.pageDown),
          ])),
          Row(children: row(<(String, RemoteButton)>[
            ('Back', RemoteButton.back), ('Sound', RemoteButton.sound), ('Next', RemoteButton.next), ('Call', RemoteButton.call),
          ])),
        ],
      ),
    );
  }

  Widget _key(String label, RemoteButton b) {
    final bool active = _flash == b;
    final Color base = b == RemoteButton.call ? const Color(0xFFD64545) : const Color(0xFF2E3644);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(4),
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : base,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active
            ? <BoxShadow>[BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 12)]
            : null,
      ),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: label.length > 3 ? 11 : 16)),
    );
  }

  Widget _diagnosticLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BleTestScreen()),
        ),
        icon: const Icon(Icons.biotech_rounded, size: 18),
        label: const Text('Advanced diagnostic'),
      ),
    );
  }

  Widget _legend() {
    const List<(String, String, IconData)> map = <(String, String, IconData)>[
      ('1 – 9', 'Choose the matching answer', Icons.filter_9_plus_rounded),
      ('Sound', 'Play the question / family voice again', Icons.volume_up_rounded),
      ('Back', 'Repeat the prompt', Icons.replay_rounded),
      ('Hint', 'Get a gentle clue', Icons.lightbulb_outline_rounded),
      ('Next', 'Move to the next step', Icons.skip_next_rounded),
      ('Call', 'Tell the caregiver help is needed', Icons.sos_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: <Widget>[
          for (final (String, String, IconData) e in map)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: <Widget>[
                Icon(e.$3, size: 22, color: AppColors.primary),
                const SizedBox(width: 12),
                SizedBox(width: 70, child: Text(e.$1, style: AppText.body().copyWith(fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Expanded(child: Text(e.$2, style: AppText.body(color: AppColors.textMuted))),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _setupSteps() {
    const List<String> steps = <String>[
      'Turn the remote on and keep it near this device.',
      'Tap “Connect remote” and allow the Bluetooth permission.',
      'Wait for “Remote connected”, then press a button to test.',
      'Open any game — the patient can now play with the remote.',
    ];
    return Container(
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Set-up', style: AppText.title().copyWith(fontSize: 16, color: AppColors.primaryDark)),
          const SizedBox(height: 8),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.primary,
                  child: Text('${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(steps[i], style: AppText.body(color: AppColors.primaryDark))),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _webNote() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Text('Use the Android app', style: AppText.title().copyWith(fontSize: 18)),
          ]),
          const SizedBox(height: 8),
          Text(
            'The physical NAWAL remote connects over Bluetooth, which works in the '
            'installed Android app. On the web every game is fully playable by touch. '
            'The button guide below still applies.',
            style: AppText.body(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
