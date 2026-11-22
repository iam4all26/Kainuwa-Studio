import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kainuwa_encoder/kainuwa_encoder.dart';

import '../models.dart';
import '../project_package.dart';

/// Packs a project with all its media into a .kainuwa file and lets the user save it.
/// Shared by the home tab and the Projects screen.
Future<void> exportProjectFile(BuildContext context, Course course) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text('Packing "${course.title}" with all its media...')),
        ]),
      ),
    ),
  );
  var closed = false;
  void close() {
    if (!closed) {
      closed = true;
      nav.pop();
    }
  }

  String? temp;
  try {
    final base = await KainuwaEncoder.filesDir();
    final dir = Directory('$base/export_tmp');
    await dir.create(recursive: true);
    final safe = course.title.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final name = '${safe.isEmpty ? 'course' : safe}.kainuwa';
    temp = '${dir.path}/$name';
    await ProjectPackage.exportTo(course, temp);
    close();
    final where = await KainuwaEncoder.saveFile(path: temp, name: name);
    say('Saved to $where');
  } catch (e) {
    close();
    final text = e.toString();
    say(text.contains('save_cancelled') ? 'Export cancelled.' : 'Could not export: $text');
  } finally {
    close();
    if (temp != null) {
      try {
        await File(temp).delete();
      } catch (_) {}
    }
  }
}
