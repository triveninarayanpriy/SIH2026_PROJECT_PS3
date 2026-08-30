import 'package:flutter/material.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_button.dart';

/// VR Simulation placeholder screen - future scope for VR headset integration
class SimulationModeScreen extends StatelessWidget {
  const SimulationModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 3),
                    gradient: const RadialGradient(
                      colors: [Color(0xFF415A77), Color(0xFF1B263B)],
                    ),
                  ),
                  child: const Icon(Icons.vrpano_rounded, size: 80, color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Text('VR Home Simulation',
                    style: AppText.gameQuestion().copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                Text(
                  'Immersive virtual reality experience\nfor familiar environment simulation',
                  textAlign: TextAlign.center,
                  style: AppText.body(color: Colors.white60).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 48),
                _FeatureRow(icon: Icons.home_rounded, text: 'Virtual home environment recreation'),
                const SizedBox(height: 16),
                _FeatureRow(icon: Icons.temple_hindu_rounded, text: 'Cultural & regional familiar places'),
                const SizedBox(height: 16),
                _FeatureRow(icon: Icons.people_rounded, text: 'Family member interactions in VR'),
                const SizedBox(height: 16),
                _FeatureRow(icon: Icons.music_note_rounded, text: 'Ambient regional music & sounds'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_connected, color: Colors.white54, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VR Headset Required', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                            Text('Connect a compatible VR headset to begin', style: TextStyle(color: Colors.white54, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                BigButton(
                  label: 'Back to Home',
                  icon: Icons.arrow_back_rounded,
                  color: const Color(0xFF415A77),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 17)),
        ),
      ],
    );
  }
}
