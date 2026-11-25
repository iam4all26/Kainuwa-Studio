import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../app_state.dart';
import '../models.dart';

/// Names of the real English voices, by speaker number.
const List<String> kRealVoices = <String>[
  'Alloy (US woman)',
  'Aoede (US woman)',
  'Bella (US woman)',
  'Heart (US woman)',
  'Jessica (US woman)',
  'Kore (US woman)',
  'Nicole (US woman)',
  'Nova (US woman)',
  'River (US woman)',
  'Sarah (US woman)',
  'Sky (US woman)',
  'Adam (US man)',
  'Echo (US man)',
  'Eric (US man)',
  'Fenrir (US man)',
  'Liam (US man)',
  'Michael (US man)',
  'Onyx (US man)',
  'Puck (US man)',
  'Santa (US man)',
  'Alice (UK woman)',
  'Emma (UK woman)',
  'Isabella (UK woman)',
  'Lily (UK woman)',
  'Daniel (UK man)',
  'Fable (UK man)',
  'George (UK man)',
  'Lewis (UK man)',
];

/// Download, test and choose the real (offline) English voice.
Future<void> showVoicesDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (c) => const _VoicesDialog());
}

class _VoicesDialog extends StatefulWidget {
  const _VoicesDialog();

  @override
  State<_VoicesDialog> createState() => _VoicesDialogState();
}

class _VoicesDialogState extends State<_VoicesDialog> {
  Map<String, dynamic> _status = <String, dynamic>{};
  Timer? _timer;
  bool _testing = false;
  String _note = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    KainuwaEncoder.stopAudio();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final s = await KainuwaEncoder.neuralStatus();
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  bool get _installed => _status['installed'] == true;
  bool get _downloading => _status['state'] == 'downloading';

  Future<void> _download() async {
    setState(() => _note = '');
    try {
      await KainuwaEncoder.neuralDownload();
    } catch (_) {
      setState(() => _note = 'The download could not start.');
    }
    await _refresh();
  }

  Future<void> _delete() async {
    final st = AppScope.read(context);
    await KainuwaEncoder.neuralDelete();
    await st.updateSettings(st.settings.copyWith(realVoice: false));
    await _refresh();
  }

  Future<void> _test() async {
    final st = AppScope.read(context);
    setState(() {
      _testing = true;
      _note = '';
    });
    try {
      final base = await KainuwaEncoder.filesDir();
      final dir = Directory('$base/kainuwa_data/tts');
      await dir.create(recursive: true);
      final path = '${dir.path}/test_voice.wav';
      await KainuwaEncoder.neuralToFile(
        'Hello. This is the real voice for your lesson. Today we will learn something new together.',
        path,
        sid: st.settings.voiceId,
      );
      await KainuwaEncoder.playAudio(path);
    } catch (e) {
      if (mounted) setState(() => _note = 'The voice could not be made: $e');
    }
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final AppSettings settings = st.settings;
    final percent = (_status['percent'] is num) ? (_status['percent'] as num).toInt() : 0;
    final failed = _status['state'] == 'error';
    return AlertDialog(
      scrollable: true,
      title: const Text('Real voice (English)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A natural English voice that works offline. It is a one-time download of about 130 MB, so use Wi-Fi. '
            'Other languages (Hausa, Arabic and so on) keep using the phone voice.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFFB5ABD6)),
          ),
          const SizedBox(height: 12),
          if (_downloading) ...[
            LinearProgressIndicator(value: percent / 100),
            const SizedBox(height: 6),
            Text('Downloading... $percent%'),
          ] else if (_installed) ...[
            const Row(children: [
              Icon(Icons.check_circle, size: 18, color: Color(0xFF7CE0A0)),
              SizedBox(width: 6),
              Text('The real voice is downloaded.'),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use the real voice'),
              subtitle: const Text('For the AI lesson creator and "Make voice from text".', style: TextStyle(fontSize: 12)),
              value: settings.realVoice,
              onChanged: (v) => st.updateSettings(settings.copyWith(realVoice: v)),
            ),
            DropdownButtonFormField<int>(
              value: settings.voiceId.clamp(0, kRealVoices.length - 1).toInt(),
              decoration: const InputDecoration(labelText: 'Voice'),
              items: [
                for (var i = 0; i < kRealVoices.length; i++) DropdownMenuItem<int>(value: i, child: Text(kRealVoices[i])),
              ],
              onChanged: (v) {
                if (v != null) st.updateSettings(settings.copyWith(voiceId: v));
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_testing ? 'Making the voice...' : 'Test this voice'),
            ),
            TextButton(onPressed: _delete, child: const Text('Delete the downloaded voice')),
          ] else ...[
            FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download),
              label: const Text('Download the real voice'),
            ),
          ],
          if (failed && !_downloading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The download stopped: ${_status['message'] ?? ''}. Check the internet and try again.',
                style: const TextStyle(color: Color(0xFFFF9B9B), fontSize: 12.5),
              ),
            ),
          if (_note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_note, style: const TextStyle(color: Color(0xFFFF9B9B), fontSize: 12.5)),
            ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
