import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

void main() {
  runApp(const KainuwaStudioApp());
}

class KainuwaStudioApp extends StatelessWidget {
  const KainuwaStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kainuwa Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B6E4F),
        useMaterial3: true,
      ),
      home: const ExportTestScreen(),
    );
  }
}

/// Step 1 proof screen: one image + one audio file become one MP4.
class ExportTestScreen extends StatefulWidget {
  const ExportTestScreen({super.key});

  @override
  State<ExportTestScreen> createState() => _ExportTestScreenState();
}

class _ExportTestScreenState extends State<ExportTestScreen> {
  String? _imagePath;
  String? _audioPath;
  bool _busy = false;
  int _progress = 0;
  bool _failed = false;
  String _status = 'Choose one image and one audio file, then export.';

  String _shortName(String path) {
    final name = path.split('/').last;
    return name.replaceFirst(RegExp(r'^\d+_'), '');
  }

  void _setMessage(String message, {bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _failed = failed;
    });
  }

  Future<void> _pickImage() async {
    try {
      final path = await KainuwaEncoder.pickImage();
      if (path != null && mounted) {
        setState(() => _imagePath = path);
      }
    } on PlatformException catch (e) {
      _setMessage('Could not choose the image: ${e.message}', failed: true);
    }
  }

  Future<void> _pickAudio() async {
    try {
      final path = await KainuwaEncoder.pickAudio();
      if (path != null && mounted) {
        setState(() => _audioPath = path);
      }
    } on PlatformException catch (e) {
      _setMessage('Could not choose the audio: ${e.message}', failed: true);
    }
  }

  Future<void> _export() async {
    final image = _imagePath;
    final audio = _audioPath;
    if (image == null || audio == null || _busy) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _failed = false;
      _status = 'Exporting. Keep this screen open.';
    });

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final output = '${Directory.systemTemp.path}/kainuwa_$stamp.mp4';
    final sub = KainuwaEncoder.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });

    try {
      await KainuwaEncoder.exportImageWithAudio(
        imagePath: image,
        audioPath: audio,
        outputPath: output,
      );
      try {
        final saved = await KainuwaEncoder.saveToMovies(
          path: output,
          name: 'Kainuwa_Test_$stamp.mp4',
        );
        _setMessage(
          'Done. The video was saved to $saved. Open it from your gallery or video player to check it.',
        );
        try {
          await File(output).delete();
        } catch (_) {}
      } on PlatformException catch (e) {
        _setMessage(
          'The video was exported but could not be copied to Movies: ${e.message}. It is at: $output',
          failed: true,
        );
      }
    } on PlatformException catch (e) {
      _setMessage('Export stopped: ${e.message}', failed: true);
    } finally {
      await sub.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    try {
      await KainuwaEncoder.cancelExport();
    } on PlatformException catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = _imagePath;
    final audio = _audioPath;
    final ready = image != null && audio != null && !_busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Kainuwa Studio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Step 1: export test',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'This screen only proves that one image and one audio file can become one MP4 on this phone.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          image == null ? 'Image: none chosen' : 'Image: ${_shortName(image)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _pickImage,
                        child: const Text('Choose'),
                      ),
                    ],
                  ),
                  if (image != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Image.file(
                        File(image),
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      audio == null ? 'Audio: none chosen' : 'Audio: ${_shortName(audio)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _pickAudio,
                    child: const Text('Choose'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress / 100 : null),
            const SizedBox(height: 8),
            Text('$_progress%'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _cancel, child: const Text('Cancel export')),
          ] else
            FilledButton(
              onPressed: ready ? _export : null,
              child: const Text('Export MP4'),
            ),
          const SizedBox(height: 16),
          Text(
            _status,
            style: TextStyle(color: _failed ? scheme.error : scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
