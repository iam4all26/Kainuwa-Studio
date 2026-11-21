import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A phone picture with a see-through screen. [hole] is the screen area in the frame's pixels.
class PhoneFrame {
  const PhoneFrame(this.id, this.name, this.asset, this.hole);

  final String id;
  final String name;
  final String asset;
  final Rect hole;
}

const double kPhoneFrameW = 887;
const double kPhoneFrameH = 1774;

const List<PhoneFrame> kPhoneFrames = [
  PhoneFrame('violet', 'Violet edge', 'assets/phones/phone_violet.png', Rect.fromLTRB(83, 51, 802, 1705)),
  PhoneFrame('island', 'Purple island', 'assets/phones/phone_island.png', Rect.fromLTRB(73, 55, 811, 1710)),
  PhoneFrame('black', 'Black', 'assets/phones/phone_black.png', Rect.fromLTRB(79, 67, 806, 1690)),
  PhoneFrame('purple', 'Purple corner camera', 'assets/phones/phone_purple.png', Rect.fromLTRB(70, 68, 812, 1688)),
  PhoneFrame('blue', 'Blue notch', 'assets/phones/phone_blue.png', Rect.fromLTRB(70, 58, 814, 1698)),
];

/// Lets the user choose one of the phone frames. Returns null when cancelled.
Future<PhoneFrame?> showPhoneFramePicker(BuildContext context) {
  return showDialog<PhoneFrame>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Choose a phone'),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.42,
          children: [
            for (final f in kPhoneFrames)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(c).pop(f),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x33808080),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(f.asset, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(f.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), maxLines: 2),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel'))],
    ),
  );
}

/// Puts [screenshot] into the screen of [frame] and saves the result as a PNG at [outPath]
/// (transparent around the phone). The screenshot fills the screen; the parts that do not fit are cut off.
Future<String> composeMockup({
  required String screenshot,
  required PhoneFrame frame,
  required String outPath,
}) async {
  final frameBytes = (await rootBundle.load(frame.asset)).buffer.asUint8List();
  final frameCodec = await ui.instantiateImageCodec(frameBytes);
  final frameImage = (await frameCodec.getNextFrame()).image;
  final shotBytes = await File(screenshot).readAsBytes();
  final shotCodec = await ui.instantiateImageCodec(shotBytes);
  final shot = (await shotCodec.getNextFrame()).image;

  final hole = frame.hole;
  final holeAspect = hole.width / hole.height;
  final shotAspect = shot.width / shot.height;
  Rect src;
  if (shotAspect > holeAspect) {
    final w = shot.height * holeAspect;
    src = Rect.fromLTWH((shot.width - w) / 2, 0, w, shot.height.toDouble());
  } else {
    final h = shot.width / holeAspect;
    src = Rect.fromLTWH(0, (shot.height - h) / 2, shot.width.toDouble(), h);
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, frameImage.width.toDouble(), frameImage.height.toDouble()));
  // A little larger than the hole, so no gap shows under the edge of the frame.
  canvas.drawImageRect(shot, src, hole.inflate(3), Paint()..filterQuality = FilterQuality.high);
  canvas.drawImage(frameImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  final picture = recorder.endRecording();
  final out = await picture.toImage(frameImage.width, frameImage.height);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  final file = File(outPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
  out.dispose();
  picture.dispose();
  shot.dispose();
  frameImage.dispose();
  shotCodec.dispose();
  frameCodec.dispose();
  return outPath;
}
