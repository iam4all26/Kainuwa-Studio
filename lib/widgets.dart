import 'package:flutter/material.dart';

import 'theme.dart';

/// Colors offered for text, shapes and backgrounds.
const List<int> kPalette = [
  0xFFFFFFFF,
  0xFF000000,
  0xFF1E1433,
  0xFF3B0F8C,
  0xFF6D28D9,
  0xFFEDE7FF,
  0xFFF6C101,
  0xFFF97316,
  0xFFDC2626,
  0xFFDB2777,
  0xFF16A34A,
  0xFF0D9488,
  0xFF2563EB,
  0xFF6B7280,
];

/// Asks for some text. Returns null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirm = 'Save',
  int maxLength = 60,
  bool multiline = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      confirm: confirm,
      maxLength: maxLength,
      multiline: multiline,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirm,
    required this.maxLength,
    required this.multiline,
  });

  final String title;
  final String label;
  final String initial;
  final String confirm;
  final int maxLength;
  final bool multiline;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        minLines: 1,
        maxLines: widget.multiline ? 5 : 1,
        keyboardType: widget.multiline ? TextInputType.multiline : TextInputType.text,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: widget.multiline ? null : (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _done, child: Text(widget.confirm)),
      ],
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A row of color circles. Returns the chosen ARGB number, or null.
Future<int?> pickColor(BuildContext context, {String title = 'Choose a color'}) {
  return showModalBottomSheet<int>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ColorSwatches(onPick: (value) => Navigator.of(sheetContext).pop(value)),
          ],
        ),
      ),
    ),
  );
}

class ColorSwatches extends StatelessWidget {
  const ColorSwatches({super.key, required this.onPick});

  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final value in kPalette)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onPick(value),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFB9A8E8), width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple purple cover used for courses until real covers exist.
class CourseCover extends StatelessWidget {
  const CourseCover({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KColors.deepPurple, KColors.purple],
        ),
      ),
      child: Icon(Icons.school_rounded, color: KColors.gold, size: size * 0.55),
    );
  }
}
