import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import 'side_sheet.dart';

/// A small panel with four arrows to move the selected item bit by bit, a speed slider and the lock switch.
/// [onChanged] is called after every move so the slide redraws; save when the panel closes.
Future<void> showMovePad(BuildContext context, {required Layer layer, required VoidCallback onChanged}) {
  return showEditorSheet<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (_) => _MovePad(layer: layer, onChanged: onChanged),
  );
}

class _MovePad extends StatefulWidget {
  const _MovePad({required this.layer, required this.onChanged});

  final Layer layer;
  final VoidCallback onChanged;

  @override
  State<_MovePad> createState() => _MovePadState();
}

class _MovePadState extends State<_MovePad> {
  /// Thousandths of the slide moved per step.
  double _speed = 4;
  Timer? _delay;
  Timer? _repeat;

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _nudge(double dx, double dy) {
    final l = widget.layer;
    if (l.locked) return;
    l.cx = (l.cx + dx * _speed / 1000).clamp(0.0, 1.0).toDouble();
    l.cy = (l.cy + dy * _speed / 1000).clamp(0.0, 1.0).toDouble();
    widget.onChanged();
  }

  void _start(double dx, double dy) {
    _stop();
    _nudge(dx, dy);
    _delay = Timer(const Duration(milliseconds: 350), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 60), (_) => _nudge(dx, dy));
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
  }

  Widget _arrow(IconData icon, double dx, double dy) {
    final off = widget.layer.locked;
    return Listener(
      onPointerDown: (_) => _start(dx, dy),
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: Container(
        width: 54,
        height: 54,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: off ? const Color(0x1A808080) : const Color(0x44808080),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 32, color: off ? Colors.white24 : Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.layer.locked;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _arrow(Icons.keyboard_arrow_up, 0, -1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _arrow(Icons.keyboard_arrow_left, -1, 0),
                    const SizedBox(width: 58, height: 58),
                    _arrow(Icons.keyboard_arrow_right, 1, 0),
                  ],
                ),
                _arrow(Icons.keyboard_arrow_down, 0, 1),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Speed', style: TextStyle(fontSize: 12)),
                  Slider(
                    value: _speed,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: _speed.round().toString(),
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                  const Text('Tap for one small step, hold to keep moving.', style: TextStyle(fontSize: 11)),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(locked ? 'Locked' : 'Lock this item'),
                    value: locked,
                    onChanged: (v) {
                      setState(() => widget.layer.locked = v);
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
