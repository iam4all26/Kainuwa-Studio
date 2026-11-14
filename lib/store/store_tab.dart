import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'store_service.dart';

class StoreTab extends StatefulWidget {
  const StoreTab({super.key, required this.active});

  /// True while this tab is the one on screen. The store loads the first time.
  final bool active;

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  final StoreService _store = StoreService.instance;
  List<StoreItem> _items = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  int _tab = 0;
  final Map<String, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    if (widget.active) _load();
  }

  @override
  void didUpdateWidget(StoreTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !_loaded && !_loading) _load();
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _store.fetchCatalog();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the store. Check your internet and the store address.\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(StoreItem item) async {
    setState(() => _progress[item.id] = 0);
    try {
      await _store.download(item, (p) {
        if (mounted) setState(() => _progress[item.id] = p);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed. $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _progress.remove(item.id));
    }
  }

  Future<void> _editAddress() async {
    final controller = TextEditingController(text: _store.base);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Store address'),
        content: TextField(
          controller: controller,
          autocorrect: false,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      await _store.setBase(controller.text);
      _loaded = false;
      await _load();
    }
    controller.dispose();
  }

  Widget _preview(StoreItem item) {
    final box = BoxDecoration(color: KColors.lavender, borderRadius: BorderRadius.circular(12));
    final installed = _store.installed.where((i) => i.id == item.id).toList();
    if (installed.isNotEmpty && item.type == 'background') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(installed.first.path), width: 96, height: 64, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(width: 96, height: 64, decoration: box)),
      );
    }
    if (item.preview.isEmpty) {
      return Container(
        width: 96,
        height: 64,
        decoration: box,
        child: Icon(item.type == 'font' ? Icons.font_download_outlined : (item.type == 'background' ? Icons.image_outlined : Icons.category_outlined)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        _store.urlFor(item.preview),
        width: 96,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(width: 96, height: 64, decoration: box, child: const Icon(Icons.image_outlined)),
      ),
    );
  }

  Widget _card(StoreItem item) {
    final installed = _store.isInstalled(item.id);
    final progress = _progress[item.id];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30265A)),
      ),
      child: Row(
        children: [
          _preview(item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (item.sizeKb > 0)
                  Text(item.sizeKb >= 1024 ? '${(item.sizeKb / 1024).toStringAsFixed(1)} MB' : '${item.sizeKb} KB',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFB5ABD6))),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(value: progress <= 0 ? null : progress),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (progress != null)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else if (installed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF22C55E)),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _store.remove(item.id),
                ),
              ],
            )
          else
            FilledButton(onPressed: () => _download(item), child: const Text('Download')),
        ],
      ),
    );
  }

  /// Items grouped under their category headings (Sans Serif, Serif, Display ...).
  List<Widget> _grouped(List<StoreItem> items) {
    final groups = <String, List<StoreItem>>{};
    for (final i in items) {
      final c = i.category.trim().isEmpty ? 'Other' : i.category.trim();
      groups.putIfAbsent(c, () => []).add(i);
    }
    if (groups.length == 1 && groups.containsKey('Other')) {
      return [for (final item in items) _card(item)];
    }
    const order = ['Hausa Ready', 'Sans Serif', 'Serif', 'Display', 'Handwriting', 'Monospace'];
    final keys = groups.keys.toList()
      ..sort((a, b) {
        int rank(String k) {
          final i = order.indexOf(k);
          return i >= 0 ? i : (k == 'Other' ? 999 : 100);
        }

        final d = rank(a).compareTo(rank(b));
        return d != 0 ? d : a.compareTo(b);
      });
    return [
      for (final k in keys) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
          child: Text(k, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        for (final item in groups[k]!) _card(item),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    const types = ['font', 'background', 'shape', 'icon'];
    final type = types[_tab];
    final shown = _items.where((i) => i.type == type).toList();
    Widget body;
    if (_loading && !_loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton(onPressed: _load, child: const Text('Try again')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _editAddress, child: const Text('Store address')),
            ],
          ),
        ),
      );
    } else if (shown.isEmpty) {
      body = const Center(child: Text('Nothing here yet.'));
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: _grouped(shown),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Store', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
                IconButton(tooltip: 'Store address', icon: const Icon(Icons.link), onPressed: _editAddress),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
              children: [
                for (final entry in const [(0, 'Fonts'), (1, 'Backgrounds'), (2, 'Shapes'), (3, 'Icons')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _tab == entry.$1,
                      onSelected: (_) => setState(() => _tab = entry.$1),
                    ),
                  ),
              ],
            ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
