import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'scene_test_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final settings = state.settings;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'Export defaults',
            style: TextStyle(fontWeight: FontWeight.w700, color: KColors.deepPurple),
          ),
          const SizedBox(height: 8),
          const Text('Video size'),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 720, label: Text('1280 x 720')),
              ButtonSegment(value: 1080, label: Text('1920 x 1080')),
            ],
            selected: {settings.videoHeight},
            onSelectionChanged: (s) =>
                state.updateSettings(settings.copyWith(videoHeight: s.first)),
          ),
          const SizedBox(height: 4),
          const Text(
            '1920 x 1080 gives sharper video but exports more slowly and warms the phone.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Text('Frame rate'),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 24, label: Text('24 per second')),
              ButtonSegment(value: 30, label: Text('30 per second')),
            ],
            selected: {settings.frameRate},
            onSelectionChanged: (s) =>
                state.updateSettings(settings.copyWith(frameRate: s.first)),
          ),
          const SizedBox(height: 4),
          const Text(
            'These choices are saved now and will be used when lessons are exported from the editor.',
            style: TextStyle(fontSize: 12),
          ),
          const Divider(height: 32),
          const Text(
            'Developer',
            style: TextStyle(fontWeight: FontWeight.w700, color: KColors.deepPurple),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.movie_creation_outlined),
            title: const Text('Export test'),
            subtitle: const Text('The step 2 test: sound mixing and one animated label.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SceneTestScreen()),
            ),
          ),
          const Divider(height: 32),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('Kainuwa Studio'),
            subtitle: Text('Version 1.0.0. Works fully offline. Your courses are saved on this phone only.'),
          ),
          if (state.loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.loadError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
