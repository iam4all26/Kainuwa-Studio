import 'package:flutter/material.dart';

import '../ai/ai_client.dart';
import '../ai/ai_config.dart';
import '../theme.dart';
import '../widgets.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiConfig? _config;
  final TextEditingController _key = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _base = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String _message = '';
  bool _hasSavedKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _base.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await AiConfig.load();
    if (!mounted) return;
    setState(() {
      _config = c;
      _model.text = c.model;
      _base.text = c.openaiBase;
      _hasSavedKey = c.key.isNotEmpty;
    });
  }

  Future<void> _pick(AiKind kind) async {
    final c = _config;
    if (c == null) return;
    c.models[c.kind.name] = _model.text.trim();
    await c.loadKeyFor(kind);
    if (!mounted) return;
    setState(() {
      _model.text = c.model;
      _key.clear();
      _hasSavedKey = c.key.isNotEmpty;
      _message = '';
    });
  }

  void _collect() {
    final c = _config!;
    c.models[c.kind.name] = _model.text.trim();
    c.openaiBase = _base.text.trim().isEmpty ? 'https://api.openai.com/v1' : _base.text.trim();
    if (_key.text.trim().isNotEmpty) c.key = _key.text.trim();
  }

  Future<void> _save() async {
    if (_config == null) return;
    _collect();
    await _config!.save();
    if (!mounted) return;
    setState(() {
      _key.clear();
      _hasSavedKey = _config!.key.isNotEmpty;
      _message = 'Saved.';
    });
  }

  Future<void> _test() async {
    if (_config == null) return;
    _collect();
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await AiClient.complete(
        _config!,
        system: 'Reply with the single word: ok',
        user: 'ok',
        maxTokens: 20,
        temperature: 0,
      );
      if (mounted) setState(() => _message = 'It works.');
    } on AiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_config == null) return;
    await _config!.removeKey();
    if (!mounted) return;
    setState(() {
      _key.clear();
      _hasSavedKey = false;
      _message = 'Key removed.';
    });
  }

  Widget _card(Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1938),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  Widget _kindChip(AiKind kind) {
    final on = _config?.kind == kind;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pick(kind),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? KColors.selected : const Color(0xFF1F1840),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF30265A)),
          ),
          child: Text(kind.label, style: TextStyle(fontWeight: on ? FontWeight.w500 : FontWeight.w400)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    return Scaffold(
      appBar: AppBar(title: const Text('AI assistant')),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _card(Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Your key stays on this phone. Your lesson goes only to the service you choose.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    HelpIcon(
                      'You use your own account with the AI service, so the cost is on your key. '
                      'The key is stored in the phone secure storage and is never saved in projects or exported files. '
                      'When you generate slides, the lesson text is sent to the service you picked.',
                      title: 'About keys',
                    ),
                  ],
                )),
                _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Service', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _kindChip(AiKind.openai),
                      const SizedBox(width: 8),
                      _kindChip(AiKind.anthropic),
                      const SizedBox(width: 8),
                      _kindChip(AiKind.gemini),
                    ]),
                    if (c.kind == AiKind.openai) ...[
                      const SizedBox(height: 14),
                      Row(children: [
                        const Text('Base address', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        HelpIcon(
                          'OpenAI style works with OpenAI, Groq, DeepSeek, OpenRouter, Together and many others. '
                          'Paste the base address from their documentation, for example https://api.groq.com/openai/v1.',
                          title: 'OpenAI style',
                        ),
                      ]),
                      TextField(
                        controller: _base,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(hintText: 'https://api.openai.com/v1'),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text('Model', style: TextStyle(fontSize: 13)),
                    TextField(
                      controller: _model,
                      decoration: InputDecoration(hintText: c.kind.defaultModel),
                    ),
                    const SizedBox(height: 14),
                    Text(_hasSavedKey ? 'API key (saved, type to replace)' : 'API key', style: const TextStyle(fontSize: 13)),
                    TextField(
                      controller: _key,
                      obscureText: !_show,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        hintText: _hasSavedKey ? '••••••••••••' : 'Paste your key',
                        suffixIcon: IconButton(
                          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _show = !_show),
                        ),
                      ),
                    ),
                  ],
                )),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _save,
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _test,
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Test'),
                      ),
                    ),
                  ],
                ),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_message, style: const TextStyle(fontSize: 13)),
                  ),
                if (_hasSavedKey)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: _remove, child: const Text('Remove saved key')),
                  ),
              ],
            ),
    );
  }
}
