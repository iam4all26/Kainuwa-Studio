import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'scene_test_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

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
            'Video quality, frame rate and file name are chosen on the Export screen of each lesson.',
            style: TextStyle(fontSize: 13),
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
