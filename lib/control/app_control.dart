import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

/// Where the owner's control file lives. Edit app_control.json in the store
/// repository on GitHub and every installed app picks it up.
const String kControlUrl = 'https://raw.githubusercontent.com/Iam4all26/245stdstr/main/app_control.json';

final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

enum ControlOutcome { offline, upToDate, updateShown, forced, maintenance, messagesShown }

/// "1.2.3" or "1.2.3+4" into numbers. Build numbers are ignored on purpose.
List<int> versionParts(String v) {
  final core = v.trim().split('+').first.split('-').first;
  final parts = core.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}

/// Negative when [a] is older than [b], zero when equal, positive when newer.
int compareVersions(String a, String b) {
  final x = versionParts(a);
  final y = versionParts(b);
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final p = i < x.length ? x[i] : 0;
    final q = i < y.length ? y[i] : 0;
    if (p != q) return p - q;
  }
  return 0;
}

class AppControl {
  AppControl._();
  static final AppControl instance = AppControl._();

  bool _running = false;
  bool _blocking = false;
  DateTime? _lastCheck;

  Future<Directory> _dir() async {
    final base = await KainuwaEncoder.filesDir();
    final dir = Directory('$base/kainuwa_data');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Map<String, dynamic>?> _fetch() async {
    final dir = await _dir();
    final cache = File('${dir.path}/app_control_cache.json');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(kControlUrl));
      request.headers.set('Cache-Control', 'no-cache');
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map<String, dynamic>) {
          await cache.writeAsString(body, flush: true);
          return data;
        }
      }
    } catch (_) {
      // Offline or the file is not there yet: use the last copy.
    } finally {
      client.close(force: true);
    }
    try {
      if (await cache.exists()) {
        final data = jsonDecode(await cache.readAsString());
        if (data is Map<String, dynamic>) return data;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> _seen() async {
    try {
      final f = File('${(await _dir()).path}/app_control_seen.json');
      if (await f.exists()) {
        final d = jsonDecode(await f.readAsString());
        if (d is Map<String, dynamic>) return d;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _saveSeen(Map<String, dynamic> seen) async {
    try {
      final f = File('${(await _dir()).path}/app_control_seen.json');
      await f.writeAsString(jsonEncode(seen), flush: true);
    } catch (_) {}
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Called when the app comes back to the front: checks again after an hour.
  Future<void> onResume() async {
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 1)) return;
    await run();
  }

  bool _inWindow(Map m) {
    final now = DateTime.now();
    final start = DateTime.tryParse('${m['start'] ?? ''}');
    if (start != null && now.isBefore(start)) return false;
    final endRaw = '${m['end'] ?? ''}';
    var end = DateTime.tryParse(endRaw);
    if (end != null) {
      if (endRaw.length <= 10) end = end.add(const Duration(days: 1));
      if (now.isAfter(end)) return false;
    }
    return true;
  }

  Future<bool?> _dialog({
    required String title,
    required String body,
    required List<Widget> Function(BuildContext) actions,
    bool dismissible = true,
  }) async {
    final ctx = appNavKey.currentState?.overlay?.context;
    if (ctx == null) return null;
    return showDialog<bool>(
      context: ctx,
      barrierDismissible: dismissible,
      builder: (context) => PopScope(
        canPop: dismissible,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1938),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: actions(context),
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await KainuwaEncoder.openUrl(url);
    } catch (_) {}
  }

  /// Reads the control file and shows what it says. Returns what happened.
  Future<ControlOutcome> run({bool manual = false}) async {
    if (_running || _blocking) return ControlOutcome.upToDate;
    _running = true;
    try {
      _lastCheck = DateTime.now();
      final data = await _fetch();
      if (data == null) return ControlOutcome.offline;
      final current = await KainuwaEncoder.appVersion();
      final seen = await _seen();

      // Maintenance switch
      final maint = data['maintenance'];
      if (maint is Map && maint['on'] == true) {
        _blocking = true;
        _running = false;
        final msg = '${maint['message'] ?? 'Kainuwa Studio is being updated. Please try again soon.'}';
        await _dialog(
          title: '${maint['title'] ?? 'Back soon'}',
          body: msg,
          dismissible: false,
          actions: (c) => [
            TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Try again')),
          ],
        );
        _blocking = false;
        await run(manual: manual);
        return ControlOutcome.maintenance;
      }

      final url = '${data['update_url'] ?? ''}';
      final notes = '${data['update_notes'] ?? ''}'.trim();
      final min = '${data['min_version'] ?? ''}';
      final latest = '${data['latest_version'] ?? ''}';

      // Forced update: cannot be closed.
      if (min.isNotEmpty && compareVersions(current, min) < 0) {
        _blocking = true;
        await _dialog(
          title: 'Update required',
          body: 'Version $current is too old. Please install version ${latest.isEmpty ? min : latest} to keep using Kainuwa Studio.'
              '${notes.isEmpty ? '' : '\n\n$notes'}',
          dismissible: false,
          actions: (c) => [
            FilledButton(
              onPressed: url.isEmpty ? null : () => _open(url),
              child: const Text('Update now'),
            ),
          ],
        );
        return ControlOutcome.forced;
      }

      var outcome = ControlOutcome.upToDate;

      // Optional update
      if (latest.isNotEmpty && compareVersions(current, latest) < 0) {
        final skippedToday = seen['skipVersion'] == latest && seen['skipDay'] == _today();
        if (manual || !skippedToday) {
          final go = await _dialog(
            title: 'Update available',
            body: 'Version $latest is ready. You have $current.${notes.isEmpty ? '' : '\n\n$notes'}',
            actions: (c) => [
              TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Later')),
              FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Update')),
            ],
          );
          if (go == true && url.isNotEmpty) {
            await _open(url);
          } else {
            seen['skipVersion'] = latest;
            seen['skipDay'] = _today();
            await _saveSeen(seen);
          }
          outcome = ControlOutcome.updateShown;
        }
      }

      // Messages
      final list = data['messages'];
      final shown = <String>{for (final e in (seen['seen'] is List ? seen['seen'] as List : const [])) '$e'};
      if (list is List) {
        for (final raw in list) {
          if (raw is! Map) continue;
          final id = '${raw['id'] ?? ''}';
          if (id.isEmpty) continue;
          if (raw['enabled'] == false) continue;
          if (!_inWindow(raw)) continue;
          final minV = '${raw['min_version'] ?? ''}';
          final maxV = '${raw['max_version'] ?? ''}';
          if (minV.isNotEmpty && compareVersions(current, minV) < 0) continue;
          if (maxV.isNotEmpty && compareVersions(current, maxV) > 0) continue;
          final once = raw['once'] != false;
          if (once && shown.contains(id)) continue;
          final link = '${raw['link'] ?? ''}';
          final label = '${raw['link_label'] ?? 'Open'}';
          final dismissible = raw['dismissible'] != false;
          shown.add(id);
          seen['seen'] = shown.toList();
          await _saveSeen(seen);
          await _dialog(
            title: '${raw['title'] ?? 'Message'}',
            body: '${raw['body'] ?? ''}',
            dismissible: dismissible,
            actions: (c) => [
              if (link.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _open(link);
                    if (dismissible) Navigator.of(c).pop(true);
                  },
                  child: Text(label),
                ),
              if (dismissible) FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('OK')),
            ],
          );
          if (outcome == ControlOutcome.upToDate) outcome = ControlOutcome.messagesShown;
        }
      }
      return outcome;
    } finally {
      _running = false;
    }
  }
}
