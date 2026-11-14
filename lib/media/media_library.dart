import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';
import 'package:photo_manager/photo_manager.dart';

import '../theme.dart';

enum MediaKind { image, video, audio }

/// Opens the in-app media library and returns the chosen file path, or null.
Future<String?> pickMedia(BuildContext context, MediaKind kind) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute<String>(builder: (_) => MediaLibraryScreen(kind: kind)),
  );
}

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key, required this.kind});

  final MediaKind kind;

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> with WidgetsBindingObserver {
  static const int _pageSize = 60;

  final ScrollController _scroll = ScrollController();
  bool _checking = true;
  bool _allowed = false;
  bool _loading = false;
  bool _hasMore = true;
  bool _opening = false;
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _album;
  final List<AssetEntity> _assets = [];
  int _page = 0;

  RequestType get _type {
    switch (widget.kind) {
      case MediaKind.image:
        return RequestType.image;
      case MediaKind.video:
        return RequestType.video;
      case MediaKind.audio:
        return RequestType.audio;
    }
  }

  String get _title {
    switch (widget.kind) {
      case MediaKind.image:
        return 'Photos';
      case MediaKind.video:
        return 'Videos';
      case MediaKind.audio:
        return 'Audio';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _loadMore();
    });
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the permission screen or the phone settings: check again.
    if (state == AppLifecycleState.resumed && !_allowed && !_checking) _start();
  }

  Future<void> _start() async {
    setState(() => _checking = true);
    PermissionState state;
    try {
      state = await PhotoManager.requestPermissionExtend(
        requestOption: PermissionRequestOption(
          androidPermission: AndroidPermission(type: RequestType.all, mediaLocation: false),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allowed = false;
      });
      return;
    }
    if (!mounted) return;
    if (!state.hasAccess) {
      setState(() {
        _checking = false;
        _allowed = false;
      });
      return;
    }
    List<AssetPathEntity> albums = [];
    try {
      albums = await PhotoManager.getAssetPathList(type: _type, onlyAll: false);
    } catch (_) {
      albums = [];
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _allowed = true;
      _albums = albums;
    });
    if (albums.isNotEmpty) await _selectAlbum(albums.first);
  }

  Future<void> _selectAlbum(AssetPathEntity album) async {
    setState(() {
      _album = album;
      _assets.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || _loading || !_hasMore) return;
    _loading = true;
    try {
      final list = await album.getAssetListPaged(page: _page, size: _pageSize);
      if (!mounted || album != _album) return;
      setState(() {
        _assets.addAll(list);
        _page += 1;
        _hasMore = list.length == _pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _hasMore = false);
    } finally {
      _loading = false;
    }
  }

  Future<void> _choose(AssetEntity asset) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final file = await asset.originFile ?? await asset.file;
      if (!mounted) return;
      if (file == null) {
        _say('That file could not be opened.');
        return;
      }
      Navigator.of(context).pop(file.path);
    } catch (_) {
      _say('That file could not be opened.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _systemPicker() async {
    try {
      String? path;
      switch (widget.kind) {
        case MediaKind.image:
          path = await KainuwaEncoder.pickImage();
          break;
        case MediaKind.video:
          path = await KainuwaEncoder.pickVideo();
          break;
        case MediaKind.audio:
          path = await KainuwaEncoder.pickAudio();
          break;
      }
      if (path != null && mounted) Navigator.of(context).pop(path);
    } catch (_) {
      // The system picker was closed.
    }
  }

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _albumMenu() {
    final album = _album;
    if (album == null) return const SizedBox.shrink();
    return PopupMenuButton<AssetPathEntity>(
      onSelected: _selectAlbum,
      itemBuilder: (_) => [
        for (final a in _albums) PopupMenuItem<AssetPathEntity>(value: a, child: Text(a.name)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(album.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _message(String text, {bool settings = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (settings)
              FilledButton(
                onPressed: _start,
                child: const Text('Try again'),
              ),
            if (settings) const SizedBox(height: 8),
            if (settings)
              OutlinedButton(
                onPressed: () => PhotoManager.openSetting(),
                child: const Text('Open app settings'),
              ),
            if (settings) const SizedBox(height: 8),
            OutlinedButton(onPressed: _systemPicker, child: const Text('Browse other files')),
          ],
        ),
      ),
    );
  }

  Widget _grid() {
    final audio = widget.kind == MediaKind.audio;
    if (audio) {
      return ListView.builder(
        controller: _scroll,
        itemCount: _assets.length,
        itemBuilder: (context, i) {
          final a = _assets[i];
          return ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: KColors.lavender, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.music_note, color: KColors.accent),
            ),
            title: Text(a.title ?? 'Audio', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_clock(a.duration)),
            onTap: () => _choose(a),
          );
        },
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _assets.length,
      itemBuilder: (context, i) {
        final a = _assets[i];
        return InkWell(
          onTap: () => _choose(a),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumb(asset: a),
              if (widget.kind == MediaKind.video)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xAA000000),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_clock(a.duration), style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_checking) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!_allowed) {
      body = _message(
        'Allow access to your media so Kainuwa Studio can show your files here.',
        settings: true,
      );
    } else if (_assets.isEmpty && !_loading && !_hasMore) {
      body = _message('Nothing found here.');
    } else {
      body = _grid();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_allowed) _albumMenu(),
          IconButton(
            tooltip: 'Browse other files',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: _systemPicker,
          ),
        ],
        bottom: _opening
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: body,
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({required this.asset});

  final AssetEntity asset;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<Uint8List?> _data =
      widget.asset.thumbnailDataWithSize(const ThumbnailSize(240, 240));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _data,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return const ColoredBox(color: Color(0xFF241C48));
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
