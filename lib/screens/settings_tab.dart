import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'scene_test_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = List.generate(5, (_) => GlobalKey());
  int _tab = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int index) {
    setState(() => _tab = index);
    final ctx = _keys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.0);
    }
  }

  Widget _card({
    required Key key,
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF30265A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: KColors.lavender,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: KColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    if (subtitle != null)
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFFB5ABD6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _choice({
    required bool on,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF2A1F5C) : const Color(0xFF1F1840),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? const Color(0xFF8B5CF6) : const Color(0xFF30265A), width: on ? 2 : 1),
        ),
        child: child,
      ),
    );
  }

  Widget _segment(String label, bool on, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? const Color(0xFF7351FF) : const Color(0xFF1F1840),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF30265A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
              if (on) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.check, size: 16)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;
    const tabs = <(IconData, String)>[
      (Icons.settings_outlined, 'General'),
      (Icons.file_download_outlined, 'Export'),
      (Icons.tune, 'Editing'),
      (Icons.smartphone, 'App'),
      (Icons.info_outline, 'About'),
    ];

    return SafeArea(
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [KColors.purple, Color(0xFF8B3DF0)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kainuwa Studio', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text('Course Video Editor', style: TextStyle(color: Color(0xFFB5ABD6))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: KColors.lavender,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.settings, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    Text('Customize Kainuwa Studio to match your workflow.',
                        style: TextStyle(color: Color(0xFFB5ABD6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: KColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF30265A)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _go(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _tab == i ? const Color(0xFF7351FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(tabs[i].$1, size: 20),
                            const SizedBox(width: 8),
                            Text(tabs[i].$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _card(
            key: _keys[0],
            icon: Icons.stay_current_portrait,
            title: 'App Layout',
            subtitle: 'Choose how you want the editor to be displayed.',
            child: Column(
              children: [
                _choice(
                  on: !settings.landscape,
                  onTap: () => state.updateSettings(settings.copyWith(orientation: 'portrait')),
                  child: Row(
                    children: [
                      const Icon(Icons.stay_current_portrait, size: 36),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Portrait', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            Text('Tall layout (phone style)', style: TextStyle(color: Color(0xFFB5ABD6))),
                          ],
                        ),
                      ),
                      Icon(!settings.landscape ? Icons.check_circle : Icons.circle_outlined),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _choice(
                  on: settings.landscape,
                  onTap: () => state.updateSettings(settings.copyWith(orientation: 'landscape')),
                  child: Row(
                    children: [
                      const Icon(Icons.stay_current_landscape, size: 36),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Landscape', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            Text('Wide layout (video style)', style: TextStyle(color: Color(0xFFB5ABD6))),
                          ],
                        ),
                      ),
                      Icon(settings.landscape ? Icons.check_circle : Icons.circle_outlined),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _card(
            key: _keys[1],
            icon: Icons.play_circle_outline,
            title: 'Export Defaults',
            subtitle: 'Set the default export options for your lessons.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Video Size (Resolution)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _segment('1280 x 720', settings.videoHeight == 720,
                        () => state.updateSettings(settings.copyWith(videoHeight: 720))),
                    const SizedBox(width: 8),
                    _segment('1920 x 1080', settings.videoHeight == 1080,
                        () => state.updateSettings(settings.copyWith(videoHeight: 1080))),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Frame Rate', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _segment('24 per second', settings.frameRate == 24,
                        () => state.updateSettings(settings.copyWith(frameRate: 24))),
                    const SizedBox(width: 8),
                    _segment('30 per second', settings.frameRate == 30,
                        () => state.updateSettings(settings.copyWith(frameRate: 30))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can still change quality, frame rate and bitrate on the Export screen of each lesson.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB5ABD6)),
                ),
              ],
            ),
          ),
          _card(
            key: _keys[2],
            icon: Icons.tune,
            title: 'Editing',
            subtitle: 'How the editor keeps your work.',
            child: const Text('Every change is saved automatically, and Undo and Redo work while a lesson is open.'),
          ),
          _card(
            key: _keys[3],
            icon: Icons.code,
            title: 'Developer Tools',
            subtitle: 'Tools for testing and advanced use.',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.movie_creation_outlined),
              title: const Text('Export Test'),
              subtitle: const Text('The step 2 test: sound mixing and one animated label.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SceneTestScreen()),
              ),
            ),
          ),
          _card(
            key: _keys[4],
            icon: Icons.info_outline,
            title: 'About Kainuwa Studio',
            child: const Text('Version 1.0.0. Works fully offline. Your courses are saved on this phone only.'),
          ),
          if (state.loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(state.loadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
