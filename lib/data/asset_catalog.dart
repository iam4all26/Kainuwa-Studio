// Generated list of the built-in asset packs.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../store/store_service.dart';

class CatalogItem {
  const CatalogItem(this.path, this.name, {this.tint = false});
  final String path;
  final String name;

  /// Downloaded SVG icons that start white and can be recoloured.
  final bool tint;

  /// True for a downloaded item (stored on the phone) and false for a built-in one.
  bool get isFile => path.startsWith('/');
}

/// Shows a catalog item, whether built in or downloaded.
Widget catalogImage(CatalogItem item, {BoxFit fit = BoxFit.contain, int? cacheWidth}) {
  if (item.isFile) {
    if (item.path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        File(item.path),
        fit: fit,
        colorFilter: item.tint ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null,
      );
    }
    return Image.file(File(item.path), fit: fit, cacheWidth: cacheWidth);
  }
  return Image.asset(item.path, fit: fit, cacheWidth: cacheWidth);
}

/// Built-in backgrounds plus the ones downloaded from the store, as one list.
List<CatalogItem> allBackgrounds() => [
      ...kBackgrounds,
      for (final i in StoreService.instance.ofType('background')) CatalogItem(i.path, i.name),
    ];

/// Built-in icons plus downloaded icons, as one list.
List<CatalogItem> allIcons() => [
      ...kIcons,
      for (final i in StoreService.instance.ofType('icon')) CatalogItem(i.path, i.name, tint: true),
    ];

/// Downloaded shapes.
List<CatalogItem> storeShapes() => [
      for (final i in StoreService.instance.ofType('shape')) CatalogItem(i.path, i.name),
    ];

const List<CatalogItem> kBackgrounds = [
  CatalogItem('assets/backgrounds/01_Royal_Purple_Waves.jpg', 'Royal Purple Waves'),
  CatalogItem('assets/backgrounds/02_Elegant_White_Waves.jpg', 'Elegant White Waves'),
  CatalogItem('assets/backgrounds/03_White_Geometric_Corners.jpg', 'White Geometric Corners'),
  CatalogItem('assets/backgrounds/04_Whiteboard_Grid.jpg', 'Whiteboard Grid'),
  CatalogItem('assets/backgrounds/05_Dark_Technology.jpg', 'Dark Technology'),
  CatalogItem('assets/backgrounds/06_Educational_Parchment.jpg', 'Educational Parchment'),
  CatalogItem('assets/backgrounds/07_Classroom_Blue.jpg', 'Classroom Blue'),
  CatalogItem('assets/backgrounds/08_Financial_Growth.jpg', 'Financial Growth'),
  CatalogItem('assets/backgrounds/09_Business_Presentation.jpg', 'Business Presentation'),
  CatalogItem('assets/backgrounds/10_Cryptocurrency_Blockchain.jpg', 'Cryptocurrency Blockchain'),
  CatalogItem('assets/backgrounds/11_Video_Production.jpg', 'Video Production'),
  CatalogItem('assets/backgrounds/12_Green_Chalkboard.jpg', 'Green Chalkboard'),
  CatalogItem('assets/backgrounds/13_AI_Innovation.jpg', 'AI Innovation'),
  CatalogItem('assets/backgrounds/14_Nature_Landscape.jpg', 'Nature Landscape'),
  CatalogItem('assets/backgrounds/15_Abstract_Geometric.jpg', 'Abstract Geometric'),
];

const List<CatalogItem> kIcons = [
  CatalogItem('assets/icons/01_Graduation_Cap.png', 'Graduation Cap'),
  CatalogItem('assets/icons/02_Books.png', 'Books'),
  CatalogItem('assets/icons/03_Open_Book.png', 'Open Book'),
  CatalogItem('assets/icons/04_Certificate.png', 'Certificate'),
  CatalogItem('assets/icons/05_School.png', 'School'),
  CatalogItem('assets/icons/06_Laptop.png', 'Laptop'),
  CatalogItem('assets/icons/07_Desktop_Monitor.png', 'Desktop Monitor'),
  CatalogItem('assets/icons/08_Smartphone.png', 'Smartphone'),
  CatalogItem('assets/icons/09_Chip.png', 'Chip'),
  CatalogItem('assets/icons/10_Cloud.png', 'Cloud'),
  CatalogItem('assets/icons/11_Briefcase.png', 'Briefcase'),
  CatalogItem('assets/icons/12_Shop.png', 'Shop'),
  CatalogItem('assets/icons/13_Growth_Chart.png', 'Growth Chart'),
  CatalogItem('assets/icons/14_Handshake.png', 'Handshake'),
  CatalogItem('assets/icons/15_Layers.png', 'Layers'),
  CatalogItem('assets/icons/16_Video.png', 'Video'),
  CatalogItem('assets/icons/17_Camera.png', 'Camera'),
  CatalogItem('assets/icons/18_Microphone.png', 'Microphone'),
  CatalogItem('assets/icons/19_Headphones.png', 'Headphones'),
  CatalogItem('assets/icons/20_Speaker.png', 'Speaker'),
  CatalogItem('assets/icons/21_Naira.png', 'Naira'),
  CatalogItem('assets/icons/22_Dollar.png', 'Dollar'),
  CatalogItem('assets/icons/23_Coins.png', 'Coins'),
  CatalogItem('assets/icons/24_Wallet.png', 'Wallet'),
  CatalogItem('assets/icons/25_Bank.png', 'Bank'),
  CatalogItem('assets/icons/26_Chat.png', 'Chat'),
  CatalogItem('assets/icons/27_Email.png', 'Email'),
  CatalogItem('assets/icons/28_Phone.png', 'Phone'),
  CatalogItem('assets/icons/29_Megaphone.png', 'Megaphone'),
  CatalogItem('assets/icons/30_Notification.png', 'Notification'),
  CatalogItem('assets/icons/31_Atom.png', 'Atom'),
  CatalogItem('assets/icons/32_Flask.png', 'Flask'),
  CatalogItem('assets/icons/33_Microscope.png', 'Microscope'),
  CatalogItem('assets/icons/34_DNA.png', 'DNA'),
  CatalogItem('assets/icons/35_Brain.png', 'Brain'),
  CatalogItem('assets/icons/36_Location.png', 'Location'),
  CatalogItem('assets/icons/37_Compass.png', 'Compass'),
  CatalogItem('assets/icons/38_Map.png', 'Map'),
  CatalogItem('assets/icons/39_Target.png', 'Target'),
  CatalogItem('assets/icons/40_Clock.png', 'Clock'),
  CatalogItem('assets/icons/41_New_Project.png', 'New Project'),
  CatalogItem('assets/icons/42_Folder.png', 'Folder'),
  CatalogItem('assets/icons/43_Play_Preview.png', 'Play Preview'),
  CatalogItem('assets/icons/44_Download.png', 'Download'),
  CatalogItem('assets/icons/45_Upload.png', 'Upload'),
  CatalogItem('assets/icons/46_Settings.png', 'Settings'),
  CatalogItem('assets/icons/47_Security_Shield.png', 'Security Shield'),
  CatalogItem('assets/icons/48_Lock.png', 'Lock'),
  CatalogItem('assets/icons/49_Sync.png', 'Sync'),
  CatalogItem('assets/icons/50_Delete.png', 'Delete'),
];

const List<CatalogItem> kIllustrations = [
  CatalogItem('assets/illustrations/01_Light_Bulb.png', 'Light Bulb'),
  CatalogItem('assets/illustrations/02_Open_Book.png', 'Open Book'),
  CatalogItem('assets/illustrations/03_Laptop.png', 'Laptop'),
  CatalogItem('assets/illustrations/04_Desktop_Monitor.png', 'Desktop Monitor'),
  CatalogItem('assets/illustrations/05_Smartphone.png', 'Smartphone'),
  CatalogItem('assets/illustrations/06_Graduation_Cap.png', 'Graduation Cap'),
  CatalogItem('assets/illustrations/07_Teacher_Presentation.png', 'Teacher Presentation'),
  CatalogItem('assets/illustrations/08_Student_Learning.png', 'Student Learning'),
  CatalogItem('assets/illustrations/09_Teamwork.png', 'Teamwork'),
  CatalogItem('assets/illustrations/10_Settings_Gears.png', 'Settings Gears'),
  CatalogItem('assets/illustrations/11_Growth_Chart.png', 'Growth Chart'),
  CatalogItem('assets/illustrations/12_Target.png', 'Target'),
  CatalogItem('assets/illustrations/13_Rocket.png', 'Rocket'),
  CatalogItem('assets/illustrations/14_Brain.png', 'Brain'),
  CatalogItem('assets/illustrations/15_Money_Bag.png', 'Money Bag'),
  CatalogItem('assets/illustrations/16_Coins.png', 'Coins'),
  CatalogItem('assets/illustrations/17_Globe.png', 'Globe'),
  CatalogItem('assets/illustrations/18_Security_Shield.png', 'Security Shield'),
  CatalogItem('assets/illustrations/19_Calendar.png', 'Calendar'),
  CatalogItem('assets/illustrations/20_Clock.png', 'Clock'),
  CatalogItem('assets/illustrations/21_Checklist.png', 'Checklist'),
  CatalogItem('assets/illustrations/22_Magnifying_Glass.png', 'Magnifying Glass'),
  CatalogItem('assets/illustrations/23_Cloud_Upload.png', 'Cloud Upload'),
  CatalogItem('assets/illustrations/24_Database.png', 'Database'),
  CatalogItem('assets/illustrations/25_Video_Camera.png', 'Video Camera'),
  CatalogItem('assets/illustrations/26_Microphone.png', 'Microphone'),
  CatalogItem('assets/illustrations/27_Headphones.png', 'Headphones'),
  CatalogItem('assets/illustrations/28_Megaphone.png', 'Megaphone'),
  CatalogItem('assets/illustrations/29_Email.png', 'Email'),
  CatalogItem('assets/illustrations/30_Network.png', 'Network'),
];

const List<CatalogItem> kSocialIcons = [
  CatalogItem('assets/icons_social/facebook.png', 'Facebook'),
  CatalogItem('assets/icons_social/instagram.png', 'Instagram'),
  CatalogItem('assets/icons_social/linkedin.png', 'LinkedIn'),
  CatalogItem('assets/icons_social/telegram.png', 'Telegram'),
  CatalogItem('assets/icons_social/tiktok.png', 'TikTok'),
  CatalogItem('assets/icons_social/whatsapp.png', 'WhatsApp'),
  CatalogItem('assets/icons_social/x.png', 'X'),
  CatalogItem('assets/icons_social/youtube.png', 'YouTube'),
];

const List<CatalogItem> kDeveloperIcons = [
  CatalogItem('assets/icons_dev/bitbucket.png', 'Bitbucket'),
  CatalogItem('assets/icons_dev/codepen.png', 'CodePen'),
  CatalogItem('assets/icons_dev/discord.png', 'Discord'),
  CatalogItem('assets/icons_dev/github.png', 'GitHub'),
  CatalogItem('assets/icons_dev/gitlab.png', 'GitLab'),
  CatalogItem('assets/icons_dev/npm.png', 'npm'),
  CatalogItem('assets/icons_dev/pinterest.png', 'Pinterest'),
  CatalogItem('assets/icons_dev/reddit.png', 'Reddit'),
  CatalogItem('assets/icons_dev/stackoverflow.png', 'Stack Overflow'),
  CatalogItem('assets/icons_dev/visual_studio_code.png', 'VS Code'),
];

const List<CatalogItem> kLanguageIcons = [
  CatalogItem('assets/icons_lang/c.png', 'C'),
  CatalogItem('assets/icons_lang/cpp.png', 'C++'),
  CatalogItem('assets/icons_lang/csharp.png', 'C#'),
  CatalogItem('assets/icons_lang/css3.png', 'CSS3'),
  CatalogItem('assets/icons_lang/dart.png', 'Dart'),
  CatalogItem('assets/icons_lang/go.png', 'Go'),
  CatalogItem('assets/icons_lang/html5.png', 'HTML5'),
  CatalogItem('assets/icons_lang/java.png', 'Java'),
  CatalogItem('assets/icons_lang/javascript.png', 'JavaScript'),
  CatalogItem('assets/icons_lang/kotlin.png', 'Kotlin'),
  CatalogItem('assets/icons_lang/php.png', 'PHP'),
  CatalogItem('assets/icons_lang/python.png', 'Python'),
  CatalogItem('assets/icons_lang/r.png', 'R'),
  CatalogItem('assets/icons_lang/ruby.png', 'Ruby'),
  CatalogItem('assets/icons_lang/rust.png', 'Rust'),
  CatalogItem('assets/icons_lang/scala.png', 'Scala'),
  CatalogItem('assets/icons_lang/swift.png', 'Swift'),
  CatalogItem('assets/icons_lang/typescript.png', 'TypeScript'),
];

// Backgrounds that are mostly dark: new text defaults to white on them.
const Set<String> kDarkBackgrounds = {
  'assets/backgrounds/01_Royal_Purple_Waves.jpg',
  'assets/backgrounds/05_Dark_Technology.jpg',
  'assets/backgrounds/08_Financial_Growth.jpg',
  'assets/backgrounds/10_Cryptocurrency_Blockchain.jpg',
  'assets/backgrounds/11_Video_Production.jpg',
  'assets/backgrounds/12_Green_Chalkboard.jpg',
  'assets/backgrounds/13_AI_Innovation.jpg',
};
