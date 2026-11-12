import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../data/asset_catalog.dart';
import '../theme.dart';
import '../widgets.dart';

class BackgroundChoice {
  const BackgroundChoice(this.type, this.value);

  /// color, asset or file
  final String type;
  final String value;
}

Future<BackgroundChoice?> showBackgroundSheet(BuildContext context) {
  return showModalBottomSheet<BackgroundChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.8, child: _BackgroundSheet()),
  );
}

class _BackgroundSheet extends StatelessWidget {
  const _BackgroundSheet();

  Future<void> _pickPhoto(BuildContext context) async {
    final navigator = Navigator.of(context);
    try {
      final path = await KainuwaEncoder.pickImage();
      if (path != null) navigator.pop(BackgroundChoice('file', path));
    } catch (_) {
      // The picker was closed or failed. Stay on this sheet.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Background', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _pickPhoto(context),
            icon: const Icon(Icons.photo_outlined),
            label: const Text('Choose a photo from this phone'),
          ),
          const SizedBox(height: 16),
          const Text('Colors', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ColorSwatches(
            onPick: (value) => Navigator.of(context).pop(BackgroundChoice('color', '$value')),
          ),
          const SizedBox(height: 16),
          const Text('Backgrounds', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 16 / 11,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: kBackgrounds.length,
            itemBuilder: (context, index) {
              final item = kBackgrounds[index];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).pop(BackgroundChoice('asset', item.path)),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox.expand(
                          child: Image.asset(item.path, fit: BoxFit.cover, cacheWidth: 400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Icons and illustrations. Returns the chosen item.
Future<CatalogItem?> showAssetSheet(BuildContext context) {
  return showModalBottomSheet<CatalogItem>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.8, child: _AssetSheet()),
  );
}

class _AssetSheet extends StatelessWidget {
  const _AssetSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add an icon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            const TabBar(tabs: [Tab(text: 'Icons'), Tab(text: 'Illustrations')]),
            Expanded(
              child: TabBarView(
                children: [
                  _PickGrid(items: kIcons, columns: 4),
                  _PickGrid(items: kIllustrations, columns: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickGrid extends StatelessWidget {
  const _PickGrid({required this.items, required this.columns});

  final List<CatalogItem> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).pop(item),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KColors.lavender),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Expanded(child: Image.asset(item.path, fit: BoxFit.contain)),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Returns rect, round or circle.
Future<String?> showShapeSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a shape', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShapeOption(
                  label: 'Rectangle',
                  child: Container(width: 64, height: 44, color: KColors.purple),
                  onTap: () => Navigator.of(sheetContext).pop('rect'),
                ),
                _ShapeOption(
                  label: 'Rounded',
                  child: Container(
                    width: 64,
                    height: 44,
                    decoration: BoxDecoration(
                      color: KColors.purple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('round'),
                ),
                _ShapeOption(
                  label: 'Circle',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: KColors.purple, shape: BoxShape.circle),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop('circle'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShapeOption extends StatelessWidget {
  const _ShapeOption({required this.label, required this.child, required this.onTap});

  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(height: 52, child: Center(child: child)),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Returns the new length in milliseconds, or null.
Future<int?> showDurationSheet(BuildContext context, int currentMs) {
  return showModalBottomSheet<int>(
    context: context,
    builder: (_) => _DurationSheet(currentMs: currentMs),
  );
}

class _DurationSheet extends StatefulWidget {
  const _DurationSheet({required this.currentMs});

  final int currentMs;

  @override
  State<_DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends State<_DurationSheet> {
  late double _seconds = (widget.currentMs / 1000).clamp(1.0, 60.0).toDouble();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scene length', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${_seconds.toStringAsFixed(1)} seconds'),
            Slider(
              value: _seconds,
              min: 1,
              max: 60,
              divisions: 118,
              onChanged: (v) => setState(() => _seconds = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop((_seconds * 1000).round()),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
