import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/nawal_remote.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../dev/ble_test_screen.dart';

/// Professional pairing + test screen for the NAWAL BLE remote.
///
/// Shows live connection status, a visual 16-button layout that lights up as the
/// patient presses keys (a real end-to-end test), and a plain-language guide to
/// what each button does. Bluetooth is Android-only, so on web it explains that.
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
    // Make sure scanning is active while the caregiver is on this screen.
    NawalRemote.instance.start();
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

  @override
  Widget build(BuildContext context) {
    final bool supported = NawalRemote.instance.isSupported;
    return Scaffold(
      backgroundColor: AppColors.skyBg,
      appBar: AppBar(title: const Text('NAWAL Remote')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: <Widget>[
              if (!supported)
                _webNote()
              else ...<Widget>[
                _statusBanner(),
                const SizedBox(height: 16),
                _remoteMock(),
                const SizedBox(height: 12),
                if (_pressCount > 0)
                  Center(
                    child: Text('$_pressCount button press${_pressCount == 1 ? '' : 'es'} received',
                        style: AppText.body(color: AppColors.success)
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => NawalRemote.instance.start(),
                        icon: const Icon(Icons.bluetooth_searching_rounded),
                        label: const Text('Scan again'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const BleTestScreen()),
                  ),
                  icon: const Icon(Icons.biotech_rounded, size: 20),
                  label: const Text('Open BLE diagnostic test'),
                ),
              ],
              const SizedBox(height: 24),
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

  Widget _statusBanner() {
    return ValueListenableBuilder<RemoteStatus>(
      valueListenable: NawalRemote.instance.statusNotifier,
      builder: (context, RemoteStatus status, _) {
        final bool on = status == RemoteStatus.connected;
        final bool scanning = status == RemoteStatus.scanning;
        final Color color = on
            ? AppColors.success
            : (scanning ? AppColors.gentleWarning : AppColors.textMuted);
        final String label = on
            ? 'Remote connected'
            : (scanning ? 'Searching for the remote…' : 'Remote not connected');
        final String sub = on
            ? 'Press any button — it should light up below.'
            : 'Turn on the remote and keep it close to this device.';
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: <Widget>[
              Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (scanning)
                    const SizedBox(
                        width: 46, height: 46, child: CircularProgressIndicator(strokeWidth: 2)),
                  Icon(on ? Icons.gamepad_rounded : Icons.bluetooth_rounded,
                      size: 30, color: color),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: AppText.title().copyWith(fontSize: 18, color: color)),
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

  /// A visual mock of the 16-button remote; the pressed key flashes.
  Widget _remoteMock() {
    List<Widget> row(List<(String, RemoteButton)> keys) => <Widget>[
          for (final (String, RemoteButton) k in keys)
            Expanded(child: _key(k.$1, k.$2)),
        ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: <Widget>[
          Row(children: row(<(String, RemoteButton)>[
            ('1', RemoteButton.one), ('2', RemoteButton.two),
            ('3', RemoteButton.three), ('Hint', RemoteButton.hint),
          ])),
          Row(children: row(<(String, RemoteButton)>[
            ('4', RemoteButton.four), ('5', RemoteButton.five),
            ('6', RemoteButton.six), ('Page ▲', RemoteButton.pageUp),
          ])),
          Row(children: row(<(String, RemoteButton)>[
            ('7', RemoteButton.seven), ('8', RemoteButton.eight),
            ('9', RemoteButton.nine), ('Page ▼', RemoteButton.pageDown),
          ])),
          Row(children: row(<(String, RemoteButton)>[
            ('Back', RemoteButton.back), ('Sound', RemoteButton.sound),
            ('Next', RemoteButton.next), ('Call', RemoteButton.call),
          ])),
        ],
      ),
    );
  }

  Widget _key(String label, RemoteButton b) {
    final bool active = _flash == b;
    final bool isCall = b == RemoteButton.call;
    final Color base = isCall ? const Color(0xFFD64545) : const Color(0xFF2E3644);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(4),
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : base,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active
            ? <BoxShadow>[BoxShadow(color: AppColors.primary.withValues(alpha: 0.6), blurRadius: 12)]
            : null,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: label.length > 3 ? 12 : 16,
        ),
      ),
    );
  }

  Widget _legend() {
    const List<(String, String, IconData)> map = <(String, String, IconData)>[
      ('1 – 9', 'Choose the matching answer', Icons.filter_9_plus_rounded),
      ('Sound', 'Play the question / family voice again', Icons.volume_up_rounded),
      ('Back / Repeat', 'Repeat the prompt', Icons.replay_rounded),
      ('Hint', 'Get a gentle clue', Icons.lightbulb_outline_rounded),
      ('Next', 'Move to the next step', Icons.skip_next_rounded),
      ('Page ▲ / ▼', 'See more answer choices', Icons.unfold_more_rounded),
      ('Call', 'Tell the caregiver help is needed', Icons.sos_rounded),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: <Widget>[
          for (final (String, String, IconData) e in map)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(e.$3, size: 22, color: AppColors.primary),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: Text(e.$1, style: AppText.body().copyWith(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.$2, style: AppText.body(color: AppColors.textMuted))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _setupSteps() {
    const List<String> steps = <String>[
      'Turn the remote on and hold it near this device.',
      'Accept the Bluetooth permission if asked.',
      'Wait for “Remote connected”, then press a button to test.',
      'Open any game — the patient can now play with the remote.',
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Set-up', style: AppText.title().copyWith(fontSize: 16, color: AppColors.primaryDark)),
          const SizedBox(height: 8),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.primary,
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(steps[i], style: AppText.body(color: AppColors.primaryDark))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _webNote() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Use the Android app', style: AppText.title().copyWith(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The physical NAWAL remote connects over Bluetooth, which works in the '
            'installed Android app. On the web version every game is fully playable '
            'by touch. The button guide below still applies.',
            style: AppText.body(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
