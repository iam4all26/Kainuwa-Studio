import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../documentary/doc_script.dart';

/// The screen where the script or production plan is pasted. Pops with the scenes that were found.
class DocScriptScreen extends StatefulWidget {
  const DocScriptScreen({super.key, required this.name});

  final String name;

  @override
  State<DocScriptScreen> createState() => _DocScriptScreenState();
}

class _DocScriptScreenState extends State<DocScriptScreen> {
  final TextEditingController _text = TextEditingController();
  List<DocScene> _scenes = <DocScene>[];
  String? _message;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _parse() {
    setState(() => _scenes = parseDocScript(_text.text));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text ?? '';
    if (value.trim().isEmpty) {
      setState(() => _message = 'Nothing was copied. Copy your script first.');
      return;
    }
    _text.text = value;
    _message = null;
    _parse();
  }

  Future<void> _openFile() async {
    try {
      final path = await KainuwaEncoder.pickAnyFile();
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      _text.text = utf8.decode(bytes, allowMalformed: true);
      _message = null;
      _parse();
    } catch (_) {
      if (mounted) setState(() => _message = 'That file could not be read as text.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final withNarration = _scenes.where((s) => s.narration.isNotEmpty).length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your script or your production plan. A plan with "Scene 1, Scene 2..." headings gives one slide per scene. '
                'A plain script gives one slide per paragraph. The words are saved on each slide and are not drawn on it.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste),
                      label: const Text('Paste'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openFile,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Open a text file'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _text,
                  onChanged: (_) => _parse(),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Your script...'),
                ),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_message!, style: const TextStyle(color: Color(0xFFFF8A80))),
                ),
              const SizedBox(height: 8),
              Text(_scenes.isEmpty ? 'No scenes found yet.' : '${_scenes.length} scenes found, $withNarration with words to say.'),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _scenes.isEmpty ? null : () => Navigator.of(context).pop(_scenes),
                child: Text(_scenes.isEmpty ? 'Create' : 'Create ${_scenes.length} slides'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
